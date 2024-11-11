// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'interaction_delegate.dart';

/// Constants for RPC methods and parameters handled by [InteractionDelegate].
abstract class InteractionDelegateConstants {
  static const kOnTapDown = 'onTapDown';
  static const kOnDoubleTapDown = 'onDoubleTapDown';
  static const kOnScroll = 'onScroll';
  static const kOnPanZoomStart = 'onPanZoomStart';
  static const kOnPanZoomUpdate = 'onPanZoomUpdate';
  static const kOnPanZoomEnd = 'onPanZoomEnd';
  static const kOnKeyUpEvent = 'onKeyUpEvent';
  static const kOnKeyDownEvent = 'onKeyDownEvent';
  static const kOnKeyRepeatEvent = 'onKeyRepeatEvent';
  static const kOnPointerMove = 'onPointerMove';
  static const kOnPointerHover = 'onPointerHover';
  static const kOnPanStart = 'onPanStart';
  static const kOnPanUpdate = 'onPanUpdate';
  static const kOnPanEnd = 'onPanEnd';

  static const kPositionX = 'positionX';
  static const kPositionY = 'positionY';
  static const kLocalPositionX = 'localPositionX';
  static const kLocalPositionY = 'localPositionY';
  static const kDeltaX = 'deltaX';
  static const kDeltaY = 'deltaY';
  static const kKeyId = 'keyId';
  static const kPhysicalKeyId = 'usbHidUsage';
  static const kButtons = 'buttons';
  static const kCharacter = 'character';
}
