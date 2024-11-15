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
import 'json_rpc_request_queue.dart';
import 'text_input_handler.dart';
import 'widget_preview.dart';

// TODO(bkonyi): handle keyboard shortcuts and clipboard operations.
/// Replays user interactions sent from the preview viewer in the actual
/// preview environment.
class InteractionDelegate {
  InteractionDelegate({required Peer connection})
      : _interactionQueue = JsonRpcRequestQueue(connection: connection) {
    registerInteractionHandlers();
    textInputHandler.register();
  }

  /// A controller used to interact with the running preview application.
  ///
  /// Provides support for replaying pointer events, scrolling, and gesture
  /// handling.
  late final controller = LiveWidgetController(WidgetsBinding.instance);

  /// Used to create pointer events to be dispatched to [controller].
  final pointerHandler = TestPointer(1, PointerDeviceKind.mouse);
  final touchPadPointerHandler = TestPointer(2, PointerDeviceKind.trackpad);

  /// Handles replaying text input to text fields.
  final textInputHandler = PreviewTextInput();

  final JsonRpcRequestQueue _interactionQueue;

  void registerInteractionHandlers() {
    _interactionQueue
      ..registerMethod(
        InteractionDelegateConstants.kOnTapDown,
        // Handles the press of the primary button.
        (Parameters params) async {
          final args = params.asMap;
          final offset = Offset(
            (args[InteractionDelegateConstants.kLocalPositionX] as num)
                .toDouble(),
            (args[InteractionDelegateConstants.kLocalPositionY] as num)
                .toDouble(),
          );
          final scaffoldOffset = controller.getTopLeft(
            find.byType(WidgetPreviewerWindowConstraints),
          );
          await controller.sendEventToBinding(
            pointerHandler.down(offset + scaffoldOffset),
          );
        },
      )
      ..registerMethod(
        InteractionDelegateConstants.kOnTapUp,
        // Handles the release of the primary button.
        (Parameters params) async {
          await controller.sendEventToBinding(pointerHandler.up());
        },
      )
      ..registerMethod(
        // Handles scrolling initiated using a mouse scroll wheel. This does
        // not handle touchpad scrolling.
        InteractionDelegateConstants.kOnScroll,
        (Parameters params) async {
          final args = params.asMap;
          final position = Offset(
            (args[InteractionDelegateConstants.kLocalPositionX] as num)
                .toDouble(),
            (args[InteractionDelegateConstants.kLocalPositionY] as num)
                .toDouble(),
          );
          final scrollDelta = Offset(
            (args[InteractionDelegateConstants.kDeltaX] as num).toDouble(),
            (args[InteractionDelegateConstants.kDeltaY] as num).toDouble(),
          );
          pointerHandler.hover(position);
          await controller.sendEventToBinding(
            pointerHandler.scroll(scrollDelta),
          );
        },
      )
      ..registerMethod(
        // Handles pointer hover events (e.g., when the cursor hovers over a
        // position for some period of time).
        InteractionDelegateConstants.kOnPointerHover,
        (Parameters params) async {
          final args = params.asMap;
          final position = Offset(
            (args[InteractionDelegateConstants.kLocalPositionX] as num)
                .toDouble(),
            (args[InteractionDelegateConstants.kLocalPositionY] as num)
                .toDouble(),
          );
          await controller.sendEventToBinding(pointerHandler.hover(position));
        },
      )
      ..registerMethod(
        // Updates the current pointer location.
        InteractionDelegateConstants.kOnPointerMove,
        (Parameters params) async {
          final args = params.asMap;
          final position = Offset(
            (args[InteractionDelegateConstants.kLocalPositionX] as num)
                .toDouble(),
            (args[InteractionDelegateConstants.kLocalPositionY] as num)
                .toDouble(),
          );
          final buttons = args[InteractionDelegateConstants.kButtons] as int;
          await controller.sendEventToBinding(
            pointerHandler.move(
              position,
              buttons: buttons,
            ),
          );
        },
      )
      ..registerMethod(
        // Indicates a pan/zoom has started. This is invoked during touchpad
        // scrolling.
        InteractionDelegateConstants.kOnPanZoomStart,
        (Parameters params) async {
          final args = params.asMap;
          final position = Offset(
            (args[InteractionDelegateConstants.kLocalPositionX] as num)
                .toDouble(),
            (args[InteractionDelegateConstants.kLocalPositionY] as num)
                .toDouble(),
          );
          await controller.sendEventToBinding(
            touchPadPointerHandler.panZoomStart(position),
          );
        },
      )
      ..registerMethod(
        // Indicates a pan/zoom is in progress and providing position deltas.
        // This is invoked during touchpad scrolling.
        InteractionDelegateConstants.kOnPanZoomUpdate,
        (Parameters params) async {
          final args = params.asMap;
          final position = Offset(
            (args[InteractionDelegateConstants.kLocalPositionX] as num)
                .toDouble(),
            (args[InteractionDelegateConstants.kLocalPositionY] as num)
                .toDouble(),
          );
          final panDelta = Offset(
            (args[InteractionDelegateConstants.kDeltaX] as num).toDouble(),
            (args[InteractionDelegateConstants.kDeltaY] as num).toDouble(),
          );
          await controller.sendEventToBinding(
            touchPadPointerHandler.panZoomUpdate(
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
        (Parameters _) async {
          await controller.sendEventToBinding(touchPadPointerHandler.panZoomEnd());
        },
      )
      ..registerMethod(
        // Invoked when a keyboard key is first pressed down.
        InteractionDelegateConstants.kOnKeyDownEvent,
        (Parameters params) async {
          final (logicalKey, physicalKey, char) = _getKeysFromParams(params);
          HardwareKeyboard.instance.handleKeyEvent(
            KeyDownEvent(
              logicalKey: logicalKey,
              physicalKey: physicalKey,
              character: char,
              timeStamp: Duration.zero,
            ),
          );
          _handleTextInput(logicalKey: logicalKey, character: char);
        },
      )
      ..registerMethod(
        // Invoked when a keyboard key is released.
        InteractionDelegateConstants.kOnKeyUpEvent,
        (Parameters params) async {
          final (logicalKey, physicalKey, _) = _getKeysFromParams(params);
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
          final (logicalKey, physicalKey, char) = _getKeysFromParams(params);
          HardwareKeyboard.instance.handleKeyEvent(
            KeyRepeatEvent(
              logicalKey: logicalKey,
              physicalKey: physicalKey,
              character: char,
              timeStamp: Duration.zero,
            ),
          );
          _handleTextInput(logicalKey: logicalKey, character: char);
        },
      );
  }

  static (LogicalKeyboardKey, PhysicalKeyboardKey, String?) _getKeysFromParams(
    Parameters params,
  ) {
    final args = params.asMap;
    final key = LogicalKeyboardKey(
      args[InteractionDelegateConstants.kKeyId] as int,
    );
    final physicalKey = PhysicalKeyboardKey.findKeyByCode(
      args[InteractionDelegateConstants.kPhysicalKeyId] as int,
    )!;
    final character = args[InteractionDelegateConstants.kCharacter] as String?;
    return (key, physicalKey, character);
  }

  void _handleTextInput({
    required LogicalKeyboardKey logicalKey,
    required String? character,
  }) {
    switch (logicalKey) {
      case LogicalKeyboardKey.backspace:
      case LogicalKeyboardKey.delete:
        textInputHandler.backspace();
      case LogicalKeyboardKey.arrowLeft:
        textInputHandler.arrowLeft();
      case LogicalKeyboardKey.arrowRight:
        textInputHandler.arrowRight();
      case LogicalKeyboardKey.home:
        textInputHandler.home();
      case LogicalKeyboardKey.end:
        textInputHandler.end();
      case LogicalKeyboardKey.enter:
        textInputHandler.enter();
      default:
        if (character != null) {
          textInputHandler.pushCharacter(character);
        }
    }
  }
}
