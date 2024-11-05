// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_rpc_2/json_rpc_2.dart';

import 'constants.dart';
import 'text_input_handler.dart';
import 'widget_preview.dart';

/// Replays user interactions sent from the preview viewer in the actual
/// preview environment.
class InteractionDelegate {

  /// A controller used to interact with the running preview application.
  ///
  /// Provides support for replaying pointer events, scrolling, and gesture
  /// handling.
  late final controller = LiveWidgetController(WidgetsBinding.instance);

  /// Used to create pointer events to be dispatched to [controller].
  final pointerHandler = TestPointer(1, PointerDeviceKind.mouse);

  /// Handles replaying text input to text fields.
  final textInputHandler = PreviewTextInput();

  /// The currently active gesture.
  /// 
  /// This is non-null only while a gesture is active.
  TestGesture? activeGesture;

  void registerInteractionHandlers({required Peer connection}) {
    connection
      ..registerMethod(
        InteractionDelegateConstants.kOnTapDown,
        // Handles single taps / clicks.
        (Parameters params) {
          final args = params.asMap;
          final offset = Offset(
            args[InteractionDelegateConstants.kLocalPositionX] as double,
            args[InteractionDelegateConstants.kLocalPositionY] as double,
          );
          final scaffoldOffset = controller.getTopLeft(
            find.byType(WidgetPreviewerWindowConstraints),
          );
          controller.tapAt(offset + scaffoldOffset);
        },
      )
      ..registerMethod(
        // Handles double taps / clicks.
        InteractionDelegateConstants.kOnDoubleTapDown,
        (Parameters params) {
          final args = params.asMap;
          final offset = Offset(
            args[InteractionDelegateConstants.kLocalPositionX] as double,
            args[InteractionDelegateConstants.kLocalPositionY] as double,
          );
          final scaffoldOffset = controller.getTopLeft(
            find.byType(WidgetPreviewerWindowConstraints),
          );
          controller.tapAt(offset + scaffoldOffset);
        },
      )
      ..registerMethod(
        // Handles scrolling initiated using a mouse scroll wheel. This does
        // not handle touchpad scrolling.
        InteractionDelegateConstants.kOnScroll,
        (Parameters params) {
          final args = params.asMap;
          final position = Offset(
            args[InteractionDelegateConstants.kPositionX] as double,
            args[InteractionDelegateConstants.kPositionY] as double,
          );
          final scrollDelta = Offset(
            args[InteractionDelegateConstants.kDeltaX] as double,
            args[InteractionDelegateConstants.kDeltaY] as double,
          );
          pointerHandler.hover(position);
          controller.sendEventToBinding(pointerHandler.scroll(scrollDelta));
        },
      )
      ..registerMethod(
        // Handles pointer hover events (e.g., when the cursor hovers over a
        // position for some period of time).
        InteractionDelegateConstants.kOnPointerHover,
        (Parameters params) {
          final args = params.asMap;
          final position = Offset(
            args[InteractionDelegateConstants.kPositionX] as double,
            args[InteractionDelegateConstants.kPositionY] as double,
          );
          controller.sendEventToBinding(pointerHandler.hover(position));
        },
      )
      ..registerMethod(
        // Updates the current pointer location.
        InteractionDelegateConstants.kOnPointerMove,
        (Parameters params) {
          final args = params.asMap;
          final position = Offset(
            args[InteractionDelegateConstants.kPositionX] as double,
            args[InteractionDelegateConstants.kPositionY] as double,
          );
          final buttons = args[InteractionDelegateConstants.kButtons] as int;
          controller.sendEventToBinding(pointerHandler.move(
            position,
            buttons: buttons,
          ));
        },
      )
      ..registerMethod(
        // Indicates a pan/zoom has started. This is invoked during touchpad
        // scrolling.
        InteractionDelegateConstants.kOnPanZoomStart,
        (Parameters params) {
          final args = params.asMap;
          final position = Offset(
            args[InteractionDelegateConstants.kPositionX] as double,
            args[InteractionDelegateConstants.kPositionY] as double,
          );
          controller.sendEventToBinding(
            pointerHandler.panZoomStart(position),
          );
        },
      )
      ..registerMethod(
        // Indicates a pan/zoom is in progress and providing position deltas.
        // This is invoked during touchpad scrolling.
        InteractionDelegateConstants.kOnPanZoomUpdate,
        (Parameters params) {
          final args = params.asMap;
          final position = Offset(
            args[InteractionDelegateConstants.kPositionX] as double,
            args[InteractionDelegateConstants.kPositionY] as double,
          );
          final panDelta = Offset(
            args[InteractionDelegateConstants.kDeltaX] as double,
            args[InteractionDelegateConstants.kDeltaY] as double,
          );
          controller.sendEventToBinding(
            pointerHandler.panZoomUpdate(
              position,
              pan: panDelta,
            ),
          );
        },
      )
      ..registerMethod(
        // Indicates a pan/zoom has finished. This is invoked during touchpad
        // scrolling.
        InteractionDelegateConstants.kOnPanZoomEnd,
        () {
          controller.sendEventToBinding(pointerHandler.panZoomEnd());
        },
      )
      ..registerMethod(
        // Indicates a pan has started. This is invoked during drag gestures.
        InteractionDelegateConstants.kOnPanStart,
        (Parameters params) async {
          final args = params.asMap;
          final position = Offset(
            args[InteractionDelegateConstants.kPositionX] as double,
            args[InteractionDelegateConstants.kPositionY] as double,
          );
          assert(activeGesture == null);
          activeGesture = await controller.startGesture(
            position,
            kind: PointerDeviceKind.mouse,
          );
        },
      )
      ..registerMethod(
        // Indicates a pan is in progress and providing position deltas.
        // This is invoked during drag gestures.
        InteractionDelegateConstants.kOnPanUpdate,
        (Parameters params) async {
          final args = params.asMap;
          final panDelta = Offset(
            args[InteractionDelegateConstants.kDeltaX] as double,
            args[InteractionDelegateConstants.kDeltaY] as double,
          );
          await activeGesture!.moveBy(panDelta);
        },
      )
      ..registerMethod(
        // Indicates a pan is completed. This is invoked during drag gestures.
        InteractionDelegateConstants.kOnPanEnd,
        (Parameters params) async {
          await activeGesture!.up();
          activeGesture = null;
        },
      )
      ..registerMethod(
        // Invoked when a keyboard key is first pressed down.
        InteractionDelegateConstants.kOnKeyDownEvent,
        (Parameters params) async {
          final (logicalKey, physicalKey) = _getKeysFromParams(params);
          HardwareKeyboard.instance.handleKeyEvent(
            KeyDownEvent(
              logicalKey: logicalKey,
              physicalKey: physicalKey,
              timeStamp: Duration.zero,
            ),
          );
        },
      )
      ..registerMethod(
        // Invoked when a keyboard key is released.
        InteractionDelegateConstants.kOnKeyUpEvent,
        (Parameters params) async {
          final (logicalKey, physicalKey) = _getKeysFromParams(params);
          HardwareKeyboard.instance.handleKeyEvent(
            KeyUpEvent(
              logicalKey: logicalKey,
              physicalKey: physicalKey,
              timeStamp: Duration.zero,
            ),
          );
        },
      )
      ..registerMethod(
        // Invoked when a keyboard key is held down.
        InteractionDelegateConstants.kOnKeyRepeatEvent,
        (Parameters params) async {
          final (logicalKey, physicalKey) = _getKeysFromParams(params);
          HardwareKeyboard.instance.handleKeyEvent(
            KeyRepeatEvent(
              logicalKey: logicalKey,
              physicalKey: physicalKey,
              timeStamp: Duration.zero,
            ),
          );
          textInputHandler.enterText(logicalKey.keyLabel);
        },
      );
  }

  static (LogicalKeyboardKey, PhysicalKeyboardKey) _getKeysFromParams(
    Parameters params,
  ) {
    final args = params.asMap;
    final key = LogicalKeyboardKey(
      args[InteractionDelegateConstants.kKeyId] as int,
    );
    final physicalKey = PhysicalKeyboardKey.findKeyByCode(
      args[InteractionDelegateConstants.kPhysicalKeyId] as int,
    )!;

    return (key, physicalKey);
  }
}
