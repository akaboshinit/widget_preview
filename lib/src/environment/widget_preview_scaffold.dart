// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: prefer_relative_imports, this won't be a relative import in the preview environment.
import 'package:widget_preview/src/environment/frame_streamer.dart';
// ignore: prefer_relative_imports, this won't be a relative import in the preview environment.
import 'package:widget_preview/src/environment/widget_preview.dart';

// ignore: uri_does_not_exist, will be generated.
import 'generated_preview.dart';

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

Future<void> main() async {
  final completer = Completer<void>();
  WidgetsFlutterBinding.ensureInitialized().addPostFrameCallback(
    (_) => completer.complete(),
  );
  final windowSizeNotifier = ValueNotifier<Size>(Size.zero);
  runApp(
    WidgetPreviewScaffold(
      windowSizeListenable: windowSizeNotifier,
    ),
  );

  // Wait for the binding to be initialized so we can initialize
  // LiveWidgetController in InteractionDelegate.
  await completer.future;
  // TODO(bkonyi): find way to prevent this server from being restarted after hot restart.
  unawaited(PreviewServer().initialize(
    host: 'localhost',
    port: 7689,
    windowSizeNotifier: windowSizeNotifier,
  ));
}

class WidgetPreviewScaffold extends StatelessWidget {
  const WidgetPreviewScaffold({super.key, required this.windowSizeListenable});

  final ValueListenable<Size> windowSizeListenable;

  @override
  Widget build(BuildContext context) {
    // ignore: undefined_method, will be present in generated_preview.dart.
    final previewList = previews();
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
          // Try to mimic the size of the render surface from the viewer.
          // TODO(bkonyi): this doesn't work very well and streamed position
          // offsets don't match correctly.
          child: ValueListenableBuilder<Size>(
            valueListenable: windowSizeListenable,
            builder: (context, size, _) {
              return Center(
                child: SizedBox.fromSize(
                  size: size,
                  child: previewView,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
