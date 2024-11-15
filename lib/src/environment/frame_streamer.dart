// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'interaction_delegate.dart';
import 'preview_binding.dart';

class ScreenSizeChangeObserver with WidgetsBindingObserver {
  ScreenSizeChangeObserver({required this.client});

  final PreviewClient client;

  @override
  void didChangeMetrics() {
    client.notifyWindowSize();
  }
}

class PreviewClient {
  PreviewClient({
    required this.server,
    required this.ws,
  }) : connection = Peer(
          StreamChannel<String>(
            ws.stream.cast(),
            StreamController(sync: true)
              ..stream.cast<String>().listen(ws.sink.add).onDone(ws.sink.close),
          ),
        ) {
    interactionDelegate = InteractionDelegate(
      connection: connection,
    );
    connection
      ..registerMethod(
        'ready',
        () {
          notifyWindowSize(
            initial: true,
          );
          PreviewWidgetsFlutterBinding.instance.addObserver(observer);
        },
      )
      ..registerMethod(
        'setWindowSize',
        (Parameters params) {
          final args = params.asMap;
          // TODO(bkonyi): use constants for these keys.
          final physicalConstraints = Size(
            (args['x'] as num).toDouble(),
            (args['y'] as num).toDouble(),
          );
          final devicePixelRatio = (args['devicePixelRatio'] as num).toDouble();
          final logicalConstraints = Size(
            (args['x'] as num).toDouble() / devicePixelRatio,
            (args['y'] as num).toDouble() / devicePixelRatio,
          );
          PreviewWidgetsFlutterBinding.instance.setViewSize(
            physicalConstraints: physicalConstraints,
            logicalConstraints: logicalConstraints,
            devicePixelRatio: devicePixelRatio,
          );
        },
      )
      // TODO(bkonyi): use result
      ..listen();
  }

  final PreviewServer server;
  final WebSocketChannel ws;
  final Peer connection;
  late final InteractionDelegate interactionDelegate;
  late final observer = ScreenSizeChangeObserver(client: this);

  void notifyWindowSize({bool initial = false}) {
    final renderView =
        PreviewWidgetsFlutterBinding.instance.rootElement!.renderObject as RenderView;
    connection.sendNotification(
      // TODO(bkonyi): create constants for these keys.
      'windowSize',
      {
        'initial': initial,
        'height': renderView.size.height,
        'width': renderView.size.width,
        'pixelRatio': renderView.flutterView.devicePixelRatio,
      },
    );
  }

  void sendFrame({required Uint8List frame}) {
    notifyWindowSize();
    ws.sink.add(frame);
  }
}

// TODO(bkonyi): consider running this in a separate isolate
class PreviewServer {
  late final HttpServer _server;

  late PreviewClient client;

  late final _previewStreamer = PreviewFrameStreamer(this);

  Future<void> initialize({
    required String host,
    required int port,
  }) async {
    final handler = Cascade().add(_webSocketHandler()).handler;
    late String errorMessage;
    Future<HttpServer?> startServer() async {
      try {
        return await io.serve(handler, host, port);
      } on SocketException catch (e) {
        errorMessage = e.message;
        if (e.osError != null) {
          errorMessage += ' (${e.osError!.message})';
        }
        errorMessage += ': ${e.address?.host}:${e.port}';
        return null;
      }
    }

    final tmpServer = await startServer();
    if (tmpServer == null) {
      throw StateError('Failed to start server: $errorMessage');
    }
    _server = tmpServer;
    final wsUri = Uri(
      scheme: 'ws',
      host: _server.address.host,
      port: _server.port,
      path: 'ws',
    );
    stderr.writeln('Preview server is listening at $wsUri');
  }

  bool sendingFrame = false;

  Future<void> sendFrame() async {
    if (sendingFrame) {
      return;
    }
    sendingFrame = true;
    final renderView =
        WidgetsBinding.instance.rootElement!.renderObject as RenderView;
    final layer = renderView.debugLayer! as OffsetLayer;
    final image = await layer.toImage(
      Offset.zero & (renderView.size * renderView.flutterView.devicePixelRatio),
    );
    final data = (await image.toByteData())!.buffer.asUint8List();
    image.dispose();
    client.sendFrame(frame: data);
    sendingFrame = false;
  }

  Handler _webSocketHandler() => webSocketHandler(
        (WebSocketChannel ws) {
          client = PreviewClient(
            server: this,
            ws: ws,
          );
          // Start streaming frames.
          _previewStreamer.initialize();
        },
      );
}

class PreviewFrameStreamer {
  PreviewFrameStreamer(this.previewServer);

  final PreviewServer previewServer;

  void initialize() {
    SchedulerBinding.instance.addPersistentFrameCallback(
      (Duration duration) => previewServer.sendFrame(),
    );
  }
}
