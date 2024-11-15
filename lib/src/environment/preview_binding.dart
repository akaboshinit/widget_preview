// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// A custom [WidgetsFlutterBinding] that allows for changing the size of the
/// root [RenderView] to match the size of the preview viewer window.
class PreviewWidgetsFlutterBinding extends WidgetsFlutterBinding {
  static PreviewWidgetsFlutterBinding ensureInitialized() {
    if (PreviewWidgetsFlutterBinding._instance == null) {
      _instance = PreviewWidgetsFlutterBinding();
    }
    return PreviewWidgetsFlutterBinding._instance!;
  }

  static PreviewWidgetsFlutterBinding get instance => BindingBase.checkInstance(
        _instance,
      );
  static PreviewWidgetsFlutterBinding? _instance;

  Size _physicalConstraints = Size.zero;
  Size _logicalConstraints = Size.zero;
  double _devicePixelRatio = 0.0;

  void setViewSize({
    required Size physicalConstraints,
    required Size logicalConstraints,
    required double devicePixelRatio,
  }) {
    _assertBindingInitialized();
    _physicalConstraints = physicalConstraints;
    _logicalConstraints = logicalConstraints;
    _devicePixelRatio = devicePixelRatio;
    handleMetricsChanged();
  }

  @override
  ViewConfiguration createViewConfigurationFor(RenderView renderView) {
    _assertBindingInitialized();
    final config = ViewConfiguration(
      physicalConstraints: BoxConstraints.expand(
        width: _physicalConstraints.width,
        height: _physicalConstraints.height,
      ),
      logicalConstraints: BoxConstraints.expand(
        width: _logicalConstraints.width,
        height: _logicalConstraints.height,
      ),
      devicePixelRatio: _devicePixelRatio,
    );
    return config;
  }

  @override
  void scheduleFrame() {
    // Bypass application lifecycle checks that would prevent frames from being
    // rendered while the preview application is backgrounded or not visible.
    scheduleForcedFrame();
  }

  void _assertBindingInitialized() {
    assert(
      _instance != null,
      'PreviewWidgetsFlutterBinding has not been initialized. '
      'PreviewWidgetsFlutterBinding must be used instead of '
      'WidgetsFlutterBinding or any other instance of BindingBase.',
    );
  }
}
