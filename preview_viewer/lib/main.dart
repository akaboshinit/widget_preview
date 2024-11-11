// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:async/async.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
// ignore: implementation_imports
import 'package:widget_preview/src/environment/constants.dart';
import 'package:stream_channel/stream_channel.dart';

void main() {
  runApp(const PreviewViewerApp());
}

typedef FrameCallback = void Function(Uint8List);

/// A custom [Peer] which supports receiving binary data over a JSON-RPC
/// connection.
///
/// [String] data is treated as JSON and [Uint8List] data is assumed to be
/// a frame event. Frame events are forwarded to the registered [FrameCallback]
/// to be decoded and rendered.
class FrameStreamingPeer extends Peer {
  FrameStreamingPeer(WebSocketChannel ws)
      : super(
          ws.transform<String>(
            StreamChannelTransformer(
              StreamTransformer<Object?, String>.fromHandlers(
                handleData: (Object? data, EventSink<String> sink) =>
                    _transformStream(data, sink),
              ),
              StreamSinkTransformer<String, Object?>.fromHandlers(
                handleData: (String data, EventSink<Object?> sink) {
                  sink.add(data);
                },
              ),
            ),
          ),
        );

  static void _transformStream(Object? data, EventSink<String> sink) {
    if (data is String) {
      sink.add(data);
    } else if (data is Uint8List) {
      _callback?.call(data);
    }
  }

  static FrameCallback? _callback;

  void registerFrameCallback(FrameCallback callback) {
    if (_callback != null) {
      throw StateError('Frame callback already registered!');
    }
    _callback = callback;
  }
}

/// Detects when the size of the preview window changes and forwards the new
/// size to the remote preview application.
class ScreenSizeChangeObserver with WidgetsBindingObserver {
  ScreenSizeChangeObserver({required this.server});

  final PreviewServer server;

  @override
  void didChangeMetrics() {
    server.sendWindowSize();
  }
}

class PreviewServer {
  PreviewServer({
    required this.ws,
    required this.onFrameData,
  }) : connection = FrameStreamingPeer(ws) {
    connection
      ..registerMethod(
        'windowSize',
        (Parameters params) {
          windowSize = Size(
            params.asMap['width'] as double,
            params.asMap['height'] as double,
          );
          pixelRatio = params.asMap['pixelRatio'];
        },
      )
      ..registerFrameCallback(
        (Uint8List frameData) {
          onFrameData(frameData, windowSize, pixelRatio);
        },
      );

    // Start listening for requests from the connection and notify the remote
    // application that we've finished initializing.
    connection.listen();
    connection.sendNotification('ready');

    // Register an observer to detect changes in the preview viewer window
    // size.
    WidgetsBinding.instance.addObserver(observer);
  }

  Future<void> get ready => ws.ready;
  final WebSocketChannel ws;

  /// Completes when the underlying connection closes.
  Future<void> get done => connection.done;

  /// The JSON-RPC connection to the remote preview application.
  final FrameStreamingPeer connection;
  late final observer = ScreenSizeChangeObserver(server: this);

  /// The current window size reported by the preview application.
  Size windowSize = Size.zero;

  /// The current pixel ratio reported by the preview application.
  double pixelRatio = 0.0;

  final void Function(Uint8List, Size, double) onFrameData;

  /// Notifies the remote preview application that the preview viewer's window
  /// size has changed.
  void sendWindowSize() async {
    // TODO(bkonyi): revisit this logic to make sure we're handling pixel ratios right.
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = view.physicalSize;
    final pixelRatio = view.devicePixelRatio;
    await connection.sendRequest('setWindowSize', {
      'x': size.width / pixelRatio,
      'y': size.height / pixelRatio,
    });
  }

  /// Forwards hover events to the preview application.
  void onPointerHover(PointerHoverEvent details) async {
    await connection.sendRequest(
      InteractionDelegateConstants.kOnPointerHover,
      {
        InteractionDelegateConstants.kPositionX: details.position.dx,
        InteractionDelegateConstants.kPositionY: details.position.dy,
      },
    );
  }

  /// Forwards event for the press of the primary button to the preview
  /// application.
  void onPointerDown(PointerDownEvent details) async {
    await connection.sendRequest(InteractionDelegateConstants.kOnTapDown, {
      InteractionDelegateConstants.kLocalPositionX: details.localPosition.dx,
      InteractionDelegateConstants.kLocalPositionY: details.localPosition.dy,
    });
  }


  /// Forwards event for the release of the primary button to the preview
  /// application.
  void onPointerUp(PointerUpEvent details) async {
    await await connection.sendRequest(InteractionDelegateConstants.kOnTapUp);
  }

  /// Forwards pointer move events (e.g., the current pointer location) to the
  /// preview application.
  void onPointerMove(PointerMoveEvent details) async {
    await connection.sendRequest(
      InteractionDelegateConstants.kOnPointerMove,
      {
        InteractionDelegateConstants.kPositionX: details.position.dx,
        InteractionDelegateConstants.kPositionY: details.position.dy,
        InteractionDelegateConstants.kButtons: details.buttons,
      },
    );
  }

  /// Forwards mouse wheel scroll events to the preview application.
  void onPointerSignal(PointerSignalEvent details) async {
    if (details is PointerScrollEvent) {
      await connection.sendRequest(
        InteractionDelegateConstants.kOnScroll,
        {
          InteractionDelegateConstants.kPositionX: details.position.dx,
          InteractionDelegateConstants.kPositionY: details.position.dy,
          InteractionDelegateConstants.kDeltaX: details.scrollDelta.dx,
          InteractionDelegateConstants.kDeltaY: details.scrollDelta.dy,
        },
      );
    }
  }

  /// Notifies the preview application that a pan/zoom event is possibly
  /// in-progress.
  ///
  /// This is an implementation detail of touchpad scrolling behavior.
  void onPointerPanZoomStart(PointerPanZoomStartEvent details) async {
    await connection.sendRequest(
      InteractionDelegateConstants.kOnPanZoomStart,
      {
        InteractionDelegateConstants.kPositionX: details.position.dx,
        InteractionDelegateConstants.kPositionY: details.position.dy,
      },
    );
  }

  /// Notifies the preview application of updates to an in-progress pan/zoom
  /// event.
  ///
  /// This is an implementation detail of touchpad scrolling behavior.
  void onPointerPanZoomUpdate(PointerPanZoomUpdateEvent details) async {
    await connection.sendRequest(
      InteractionDelegateConstants.kOnPanZoomUpdate,
      {
        InteractionDelegateConstants.kPositionX: details.position.dx,
        InteractionDelegateConstants.kPositionY: details.position.dy,
        InteractionDelegateConstants.kDeltaX: details.pan.dx,
        InteractionDelegateConstants.kDeltaY: details.pan.dy,
      },
    );
  }

  /// Notifies the preview application that a pan/zoom event has concluded.
  ///
  /// This is an implementation detail of touchpad scrolling behavior.
  void onPointerPanZoomEnd(PointerPanZoomEndEvent details) async {
    await connection.sendRequest(InteractionDelegateConstants.kOnPanZoomEnd);
  }

  /// Forwards key presses to the preview application.
  void onKeyEvent(
    KeyEvent event,
  ) async {
    await connection.sendRequest(
      switch (event) {
        KeyDownEvent _ => InteractionDelegateConstants.kOnKeyDownEvent,
        KeyUpEvent _ => InteractionDelegateConstants.kOnKeyUpEvent,
        KeyRepeatEvent _ => InteractionDelegateConstants.kOnKeyRepeatEvent,
        _ => throw StateError('Unexpected KeyEvent: ${event.runtimeType}'),
      },
      {
        InteractionDelegateConstants.kKeyId: event.logicalKey.keyId,
        InteractionDelegateConstants.kPhysicalKeyId:
            event.physicalKey.usbHidUsage,
        InteractionDelegateConstants.kCharacter: event.character,
      },
    );
  }
}

class PreviewViewerApp extends StatelessWidget {
  const PreviewViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Widget Preview Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PreviewViewer(),
    );
  }
}

/// Streams frames from and user interactions to a remote Widget Preview
/// application instance over a [WebSocketChannel].
class PreviewViewer extends StatefulWidget {
  const PreviewViewer({super.key});

  @override
  State<PreviewViewer> createState() => _PreviewViewerState();
}

class _PreviewViewerState extends State<PreviewViewer> {
  late PreviewServer server;
  final focusNode = FocusNode();
  final frameDataListenable = ValueNotifier<ui.Image?>(null);

  @override
  void initState() {
    super.initState();
    server = PreviewServer(
      ws: WebSocketChannel.connect(
        // TODO(bkonyi): make this configurable.
        Uri.parse('ws://localhost:7689/ws'),
      ),
      onFrameData: onFrameData,
    );
    // Send the initial window size to the preview application so it can resize
    // its render surface to match.
    server.sendWindowSize();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  /// Decodes a frame based on the most recent window size reported by the
  /// remote preview application and sets it as the current frame to be
  /// displayed by the UI.
  void onFrameData(Uint8List frameData, Size size, double pixelRatio) {
    ui.decodeImageFromPixels(
      frameData,
      (size.width * pixelRatio).toInt(),
      (size.height * pixelRatio).toInt(),
      ui.PixelFormat.rgba8888,
      (ui.Image image) {
        frameDataListenable.value = image;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FutureBuilder(
        future: server.ready,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Text('Connecting...');
          }
          return KeyboardListener(
            autofocus: true,
            focusNode: focusNode,
            onKeyEvent: server.onKeyEvent,
            child: Listener(
              onPointerDown: server.onPointerDown,
              onPointerUp: server.onPointerUp,
              onPointerMove: server.onPointerMove,
              onPointerHover: server.onPointerHover,
              onPointerSignal: server.onPointerSignal,
              onPointerPanZoomStart: server.onPointerPanZoomStart,
              onPointerPanZoomUpdate: server.onPointerPanZoomUpdate,
              onPointerPanZoomEnd: server.onPointerPanZoomEnd,
              child: ValueListenableBuilder<ui.Image?>(
                valueListenable: frameDataListenable,
                builder: (context, frameData, _) {
                  if (frameData == null) {
                    return Text('No frame available');
                  }
                  return SizedBox.fromSize(
                    size: server.windowSize,
                    child: RawImage(
                      image: frameData,
                      width: server.windowSize.width,
                      height: server.windowSize.height,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
