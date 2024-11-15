// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'frame_streamer.dart';
import 'preview_binding.dart';
import 'widget_preview.dart';

/// Custom [AssetBundle] used to map original asset paths from the parent
/// project to those in the preview project.
class PreviewAssetBundle extends PlatformAssetBundle {
  // Assets shipped via package dependencies have paths that start with
  // 'packages'.
  static const _kPackagesPrefix = 'packages';

  @override
  Future<ByteData> load(String key) {
    // These assets are always present or are shipped via a package and aren't
    // actually located in the parent project, meaning their paths did not need
    // to be modified.
    if (key == 'AssetManifest.bin' ||
        key == 'AssetManifest.json' ||
        key == 'FontManifest.json' ||
        key.startsWith(_kPackagesPrefix)) {
      return super.load(key);
    }
    // Other assets are from the parent project. Map their keys to those found
    // in the pubspec.yaml of the preview environment.
    return super.load('../../$key');
  }

  @override
  Future<ImmutableBuffer> loadBuffer(String key) async {
    return await ImmutableBuffer.fromAsset(
      key.startsWith(_kPackagesPrefix) ? key : '../../$key',
    );
  }
}

/// Main entrypoint for the widget previewer.
///
/// We don't actually define this as `main` to avoid copying this file into
/// the preview scaffold project which prevents us from being able to use hot
/// restart to iterate on this file.
Future<void> mainImpl({
  required List<WidgetPreview> Function() previewsProvider,
}) async {
  BindingBase.debugZoneErrorsAreFatal = true;
  final completer = Completer<void>();

  PreviewWidgetsFlutterBinding.ensureInitialized().addPostFrameCallback(
    (_) => completer.complete(),
  );
  runApp(
    WidgetPreviewScaffold(
      previewsProvider: previewsProvider,
    ),
  );

  // Wait for the binding to be initialized so we can initialize
  // LiveWidgetController in InteractionDelegate.
  await completer.future;

  // TODO(bkonyi): find way to prevent this server from being restarted after hot restart.
  unawaited(PreviewServer().initialize(
    host: 'localhost',
    port: 7689,
  ));
}

class WidgetPreviewScaffold extends StatelessWidget {
  const WidgetPreviewScaffold({super.key, required this.previewsProvider});

  final List<WidgetPreview> Function() previewsProvider;

  @override
  Widget build(BuildContext context) {
    final previewList = previewsProvider();
    Widget previewView;
    if (previewList.isEmpty) {
      previewView = const Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            // TODO: consider including details on how to get started
            // with Widget Previews.
            child: Text(
              'No previews available',
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      );
    } else {
      previewView = LayoutBuilder(
        builder: (context, constraints) {
          return WidgetPreviewerWindowConstraints(
            constraints: constraints,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final preview in previewList) preview,
                ],
              ),
            ),
          );
        },
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: DefaultAssetBundle(
          bundle: PreviewAssetBundle(),
          child: previewView,
        ),
      ),
    );
  }
}
