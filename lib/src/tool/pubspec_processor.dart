// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'constants.dart';
import 'utils.dart';

final logger = Logger.root;

/// Handles adding package dependencies, assets, and fonts to the preview
/// scaffolding project's Pubspec.
// TODO(bkonyi): Check for new assets and fonts after first run.
class PubspecProcessor {
  PubspecProcessor({required this.projectRoot});

  /// The root of the parent project.
  final Directory projectRoot;

  static const _kPubspecYaml = 'pubspec.yaml';

  // Pubspec keys.
  static const _kName = 'name';
  static const _kFlutter = 'flutter';
  static const _kAssets = 'assets';
  static const _kAsset = 'asset';
  static const _kFonts = 'fonts';
  static const _kFontFamily = 'family';
  static const _kFontWeight = 'weight';
  static const _kFontStyle = 'style';
  static const _kGenerate = 'generate';

  final previewEnvironmentPubspec = File(
    path.join(previewScaffoldProjectPath, _kPubspecYaml),
  );

  // Returns the project name and the boolean value of the 'generate' key.
  // If 'generate' is true, package:flutter_gen should be depended on.
  Future<(String, bool)> _processParentPubspec() async {
    final parentPubspec = File(path.join(projectRoot.path, _kPubspecYaml));
    if (!await parentPubspec.exists()) {
      // TODO(bkonyi): throw a better error.
      throw StateError('Could not find pubspec.yaml');
    }

    // Read the asset and font information from the parent project's pubspec,
    // updating paths so the relative paths will point to the original assets
    // from the preview project.
    final pubspecContents = await parentPubspec.readAsString();
    final yaml = loadYamlDocument(pubspecContents).contents.value as YamlMap;
    final projectName = yaml[_kName] as String;
    final flutterYaml = yaml[_kFlutter] as YamlMap;

    final assets = flutterYaml.containsKey(_kAssets)
        ? (flutterYaml[_kAssets] as YamlList).value.cast<String>()
        : <String>[];
    final fontsYaml = flutterYaml.containsKey(_kFonts)
        ? (flutterYaml[_kFonts] as YamlList).value.cast<YamlMap>()
        : <YamlMap>[];

    // Write the asset and font information to the preview scaffold's pubspec.
    // TODO(bkonyi): handle assets that are found under deferred-components.
    final editor = YamlEditor(await previewEnvironmentPubspec.readAsString());
    _updateAssets(assets: assets, pubspec: editor);
    _updateFonts(fontsYaml: fontsYaml, pubspec: editor);

    await previewEnvironmentPubspec.writeAsString(editor.toString());

    return (
      projectName,
      flutterYaml.containsKey(_kGenerate)
          ? flutterYaml[_kGenerate] as bool
          : false
    );
  }

  void _updateAssets({
    required List<String> assets,
    required YamlEditor pubspec,
  }) {
    // Reference the assets from the parent project.
    if (assets.isNotEmpty) {
      logger.info(
        'Added assets from the parent project to $previewEnvironmentPubspec.',
      );
      pubspec.update(
        [_kFlutter, _kAssets],
        assets.map(_processAssetPath).toList(),
      );
    }
  }

  void _updateFonts({
    required List<YamlMap> fontsYaml,
    required YamlEditor pubspec,
  }) {
    final fonts = <Map<String, Object>>[
      for (final familyYaml in fontsYaml)
        <String, Object>{
          _kFontFamily: familyYaml[_kFontFamily] as String,
          _kFonts: <Map<String, Object>>[
            for (final fontsYaml in familyYaml[_kFonts] as YamlList)
              <String, Object>{
                // Reference the assets from the parent project.
                _kAsset: _processAssetPath(
                    (fontsYaml as YamlMap)[_kAsset] as String),
                if (fontsYaml.containsKey(_kFontWeight))
                  _kFontWeight: fontsYaml[_kFontWeight] as int,
                if (fontsYaml.containsKey(_kFontStyle))
                  _kFontStyle: fontsYaml[_kFontStyle] as String,
              }
          ]
        }
    ];

    if (fonts.isNotEmpty) {
      logger.info(
        'Added fonts from the parent project to $previewEnvironmentPubspec.',
      );
      pubspec.update([_kFlutter, _kFonts], fonts);
    }
  }

  static String _processAssetPath(String asset) {
    if (!asset.startsWith('packages')) {
      return '../../$asset';
    }
    return asset;
  }

  /// Manually adds an entry for package:flutter_gen to the preview scaffold's
  /// package_config.json if the target project makes use of localization.
  ///
  /// The Flutter Tool does this when running a Flutter project with
  /// localization instead of modifying the user's pubspec.yaml to depend on it
  /// as a path dependency. Unfortunately, the preview scaffold still needs to
  /// add it directly to its package_config.json as the generated package name
  /// isn't actually flutter_gen, which pub doesn't really like, and using the
  /// actual package name will break applications which import
  /// package:flutter_gen.
  Future<void> _addFlutterGenToPackageConfig() async {
    final packageConfigPath = path.join(
      projectRoot.path,
      '.dart_tool',
      'preview_scaffold',
      '.dart_tool',
      'package_config.json',
    );
    final packageConfig = File(packageConfigPath);
    if (!packageConfig.existsSync()) {
      throw StateError(
        // ignore: lines_longer_than_80_chars
        "Could not find preview project's package_config.json at $packageConfigPath",
      );
    }
    final packageConfigJson =
        json.decode(packageConfig.readAsStringSync()) as Map<String, Object?>;
    (packageConfigJson['packages'] as List).cast<Map<String, String>>().add(
      const <String, String>{
        'name': 'flutter_gen',
        'rootUri': '../../flutter_gen',
        'languageVersion': '2.12',
      },
    );
    packageConfig.writeAsStringSync(json.encode(packageConfigJson));
    logger.info('Added flutter_gen dependency to $packageConfigPath');
  }

  /// Initializes the pubspec.yaml for the preview scaffolding project.
  ///
  /// This adds dependencies on package:widget_preview and the parent project,
  /// while also populating the initial set of assets and fonts.
  Future<void> initialize() async {
    final (projectName, generate) = await _processParentPubspec();

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

    checkExitCode(
      description: 'Adding pub dependencies',
      failureMessage: 'Failed to add dependencies to pubspec.yaml!',
      result: await Process.run('flutter', args),
    );

    if (generate) {
      await _addFlutterGenToPackageConfig();
    }
  }
}
