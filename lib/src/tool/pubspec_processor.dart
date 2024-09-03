// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'constants.dart';

final logger = Logger.root;

typedef PubspecFields = ({
  String projectName,
  List<String> assets,
  List<Map<String, Object>> fonts,
});

class PubspecProcessor {
  PubspecProcessor({required this.projectRoot});

  final Directory projectRoot;

  Future<String> _populateAssetsAndFonts() async {
    final parentPubspec = File(path.join(projectRoot.path, 'pubspec.yaml'));
    if (!await parentPubspec.exists()) {
      // TODO(bkonyi): throw a better error.
      throw StateError('Could not find pubspec.yaml');
    }
    final pubspecContents = await parentPubspec.readAsString();
    final yaml = loadYamlDocument(pubspecContents).contents.value as YamlMap;
    final projectName = yaml['name'] as String;
    final flutterYaml = yaml['flutter'] as YamlMap;
    final assets = (flutterYaml['assets'] as YamlList).value.cast<String>();
    final fontsYaml = (flutterYaml['fonts'] as YamlList).value.cast<YamlMap>();
    final fonts = <Map<String, Object>>[
      for (final familyYaml in fontsYaml)
        <String, Object>{
          'family': familyYaml['family'] as String,
          'fonts': <Map<String, Object>>[
            for (final fontsYaml in familyYaml['fonts'] as YamlList)
              <String, Object>{
                'asset': '../../${(fontsYaml as YamlMap)['asset']}',
                if (fontsYaml.containsKey('weight'))
                  'weight': fontsYaml['weight'] as int,
                if (fontsYaml.containsKey('style'))
                  'style': fontsYaml['style'] as String,
              }
          ]
        }
    ];

    final previewEnvironmentPubspec = File(
      path.join(previewScaffoldProjectPath, 'pubspec.yaml'),
    );
    final editor = YamlEditor(await previewEnvironmentPubspec.readAsString());

    if (assets.isNotEmpty) {
      // Reference the assets from the parent project.
      editor.update(
        ['flutter', 'assets'],
        assets.map((e) => '../../$e').toList(),
      );
    }

    if (fonts.isNotEmpty) {
      editor.update(['flutter', 'fonts'], fonts);
    }

    await previewEnvironmentPubspec.writeAsString(editor.toString());

    // TODO(bkonyi): don't return this.
    return projectName;
  }

  Future<void> initialize() async {
    final projectName = await _populateAssetsAndFonts();

    logger.info(
      'Adding package:widget_preview and $projectName '
      'dependency...',
    );

    final widgetPreviewPath = path.dirname(
      path.dirname(
        Platform.script.toFilePath(),
      ),
    );

    final args = [
      'pub',
      'add',
      '--directory=.dart_tool/preview_scaffold',
      // TODO(bkonyi): add dependency on published package:widget_preview or
      // remove this if it's shipped with package:flutter
      'widget_preview:{"path":"$widgetPreviewPath"}',
      '$projectName:{"path":"${projectRoot.path}"}',
    ];

    final result = await Process.run('flutter', args);
    if (result.exitCode != 0) {
      logger.severe('Failed to add dependencies to pubspec.yaml');
      logger.severe('STDOUT: ${result.stdout}');
      logger.severe('STDERR: ${result.stderr}');

      // TODO(bkonyi): throw a better error.
      throw StateError('Failed to add dependencies to pubspec.yaml');
    }
  }
}
