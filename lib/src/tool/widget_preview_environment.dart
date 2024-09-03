// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:code_builder/code_builder.dart' as builder;
import 'package:dart_style/dart_style.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart';
import 'package:yaml/yaml.dart';
import '../environment/widget_preview_scaffold.dart';

import 'flutter_tools_daemon.dart';
import 'utils.dart';

/// Clears preview scaffolding state on each run.
///
/// Set to false for release.
const developmentMode = true;

const previewScaffoldProjectPath = '.dart_tool/preview_scaffold/';

final logger = Logger.root;

typedef PreviewMapping = Map<String, List<String>>;

class WidgetPreviewEnvironment {
  late final String _vmServiceInfoPath;
  final _pathToPreviews = PreviewMapping();
  StreamSubscription<WatchEvent>? _fileWatcher;

  Future<void> start(Directory projectRoot) async {
    // TODO(bkonyi): consider parallelizing initializing the scaffolding
    // project and finding the previews.
    await _ensurePreviewScaffoldExists(projectRoot);
    _pathToPreviews.addAll(_findPreviewFunctions(projectRoot));
    await _populatePreviewsInScaffold(_pathToPreviews);
    await _runPreviewEnvironment();
    await _cleanup();
  }

  Future<void> _cleanup() async {
    await _fileWatcher?.cancel();
  }

  Future<String> _getProjectNameFromPubspec(Directory projectRoot) async {
    final pubspec = File(path.join(projectRoot.path, 'pubspec.yaml'));
    if (!await pubspec.exists()) {
      // TODO(bkonyi): throw a better error.
      throw StateError('Could not find pubspec.yaml');
    }
    final pubspecContents = await pubspec.readAsString();
    final yaml = loadYamlDocument(pubspecContents).contents.value as YamlMap;
    return yaml['name'] as String;
  }

  Future<void> _ensurePreviewScaffoldExists(Directory projectRoot) async {
    // TODO(bkonyi): check for .dart_tool explicitly
    if (developmentMode) {
      final previewScaffoldProject = Directory(previewScaffoldProjectPath);
      if (await previewScaffoldProject.exists()) {
        await previewScaffoldProject.delete(recursive: true);
      }
    }
    if (await Directory(previewScaffoldProjectPath).exists()) {
      logger.info('Preview scaffolding exists!');
      return;
    }

    // TODO(bkonyi): check exit code.
    logger.info('Creating $previewScaffoldProjectPath...');
    await Process.run('flutter', [
      'create',
      '--platforms=windows,linux,macos',
      '.dart_tool/preview_scaffold',
    ]);

    if (!(await Directory(previewScaffoldProjectPath).exists())) {
      logger.severe('Could not create $previewScaffoldProjectPath!');
      throw StateError('Could not create $previewScaffoldProjectPath');
    }

    logger.info(Uri(path: previewScaffoldProjectPath).resolve('lib/main.dart'));
    logger.info('Writing preview scaffolding entry point...');
    await File(
      Uri(path: previewScaffoldProjectPath).resolve('lib/main.dart').toString(),
    ).writeAsString(
      widgetPreviewScaffold,
      mode: FileMode.write,
    );

    // TODO(bkonyi): add dependency on published package:widget_preview or
    // remove this if it's shipped with package:flutter
    final projectName = await _getProjectNameFromPubspec(projectRoot);
    logger.info('Adding package:widget_preview and $projectName dependency...');
    final widgetPreviewPath = path.dirname(
      path.dirname(
        Platform.script.toFilePath(),
      ),
    );
    final args = [
      'pub',
      'add',
      '--directory=.dart_tool/preview_scaffold',
      // TODO(bkonyi): don't hardcode
      'widget_preview:{"path":"$widgetPreviewPath"}',
      '$projectName:{"path":"."}',
    ];
    // TODO(bkonyi): check exit code.
    final result = await Process.run('flutter', args);
    if (result.exitCode != 0) {
      logger.severe('Failed to add dependencies to pubspec.yaml');
      logger.severe('STDOUT: ${result.stdout}');
      logger.severe('STDERR: ${result.stderr}');

      // TODO(bkonyi): throw a better error.
      throw StateError('Failed to add dependencies to pubspec.yaml');
    }

    // Generate an empty 'lib/generated_preview.dart'
    logger.info(
      'Generating empty ${previewScaffoldProjectPath}lib/generated_preview.dart',
    );

    await _populatePreviewsInScaffold(const <String, List<String>>{});

    logger.info('Performing initial build...');
    await _initialBuild();

    logger.info('Preview scaffold initialization complete!');

    // TODO(bkonyi): create a symlink to the assets directory and update the
    // pubspec with the asset entries.
  }

  Future<void> _initialBuild() async {
    await runInDirectoryScope(
      path: previewScaffoldProjectPath,
      callback: () async {
        assert(Platform.isLinux || Platform.isMacOS || Platform.isWindows);
        final args = <String>[
          'build',
          // This assumes the device ID string matches the subcommand name.
          PlatformUtils.getDeviceIdForPlatform(),
          '--device-id=${PlatformUtils.getDeviceIdForPlatform()}',
          '--debug',
        ];
        // TODO(bkonyi): check exit code.
        await Process.run('flutter', args);
      },
    );
  }

  /// Search for functions annotated with `@Preview` in the current project.
  PreviewMapping _findPreviewFunctions(FileSystemEntity entity) {
    final collection = AnalysisContextCollection(
      includedPaths: [entity.absolute.path],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    final previews = PreviewMapping();

    for (final context in collection.contexts) {
      logger.info('Finding previews in ${context.contextRoot.root.path} ...');

      for (final filePath in context.contextRoot.analyzedFiles()) {
        if (!filePath.endsWith('.dart')) {
          continue;
        }

        final lib = context.currentSession.getParsedLibrary(filePath);
        if (lib is ParsedLibraryResult) {
          for (final unit in lib.units) {
            final previewEntries =
                previews.putIfAbsent(unit.uri.toString(), () => <String>[]);
            for (final entity in unit.unit.childEntities) {
              if (entity is FunctionDeclaration &&
                  !entity.name.toString().startsWith('_')) {
                var foundPreview = false;
                for (final annotation in entity.metadata) {
                  if (annotation.name.name == 'Preview') {
                    // What happens if the annotation is applied multiple times?
                    foundPreview = true;
                    break;
                  }
                }
                if (foundPreview) {
                  logger.info('Found preview at:');
                  logger.info('File path: ${unit.uri}');
                  logger.info('Preview function: ${entity.name}');
                  logger.info('');
                  previewEntries.add(entity.name.toString());
                }
              }
            }
          }
        } else {
          logger.warning('Unknown library type at $filePath: $lib');
        }
      }
    }
    return previews;
  }

  Future<void> _populatePreviewsInScaffold(PreviewMapping previews) async {
    final lib = builder.Library(
      (b) => b.body.addAll(
        [
          builder.Directive.import(
            'package:widget_preview/widget_preview.dart',
          ),
          builder.Method(
            (b) => b
              ..body = builder.literalList(
                [
                  for (final MapEntry(
                        key: String path,
                        value: List<String> previewMethods
                      ) in previews.entries) ...[
                    for (final method in previewMethods)
                      builder.refer(method, path).spread.call([]),
                  ],
                ],
              ).code
              ..name = 'previews'
              ..returns = builder.refer('List<WidgetPreview>'),
          )
        ],
      ),
    );
    final emitter = builder.DartEmitter.scoped(useNullSafetySyntax: true);
    await File(
      Directory.current.absolute.uri
          .resolve('.dart_tool/preview_scaffold/lib/generated_preview.dart')
          .toFilePath(),
    ).writeAsString(
      DartFormatter().format('${lib.accept(emitter)}'),
    );
  }

  Future<void> _runPreviewEnvironment() async {
    final projectDir = Directory.current.uri.toFilePath();
    final tempDir = await Directory.systemTemp.createTemp();
    _vmServiceInfoPath = path.join(tempDir.path, 'preview_vm_service.json');
    final process = await runInDirectoryScope<Process>(
      path: previewScaffoldProjectPath,
      callback: () async {
        final args = [
          'run',
          '--machine',
          // ignore: lines_longer_than_80_chars
          '--use-application-binary=${PlatformUtils.prebuiltApplicationBinaryPath}',
          '--device-id=${PlatformUtils.getDeviceIdForPlatform()}',
          '--vmservice-out-file=$_vmServiceInfoPath',
        ];
        logger.info('Running "flutter $args"');
        return await Process.start('flutter', args);
      },
    );

    final daemon = Daemon(
      onAppStart: (String appId) async {
        final serviceInfo = await File(_vmServiceInfoPath).readAsString();
        logger.info('Preview VM service can be found at: $serviceInfo');
        // Immediately trigger a hot restart on app start to update state
        process.stdin.writeln(
          DaemonRequest.hotRestart(appId: appId).encode(),
        );
      },
    );

    process.stdout.transform(utf8.decoder).listen((e) {
      logger.info('[STDOUT] ${e.withNoTrailingNewLine}');
      daemon.handleEvent(e);
    });

    process.stderr.transform(utf8.decoder).listen((e) {
      if (e == '\n') return;
      logger.info('[STDERR] ${e.withNoTrailingNewLine}');
    });

    _fileWatcher = Watcher(projectDir).events.listen((event) async {
      if (daemon.appId == null ||
          !event.path.endsWith('.dart') ||
          event.path.endsWith('generated_preview.dart')) return;
      final eventPath = event.path.asFilePath;
      logger.info('Detected change in $eventPath. Performing reload...');

      final filePreviewsMapping = _findPreviewFunctions(File(event.path));
      if (filePreviewsMapping.length > 1) {
        logger.warning('Previews from more than one file were detected!');
        logger.warning('Previews: $filePreviewsMapping');
      }
      final MapEntry(key: uri, value: filePreviews) =
          filePreviewsMapping.entries.first;
      logger.info('Updated previews for $uri: $filePreviews');
      if (filePreviews.isNotEmpty) {
        final currentPreviewsForFile = _pathToPreviews[uri];
        if (filePreviews != currentPreviewsForFile) {
          _pathToPreviews[uri] = filePreviews;
        }
      } else {
        _pathToPreviews.remove(uri);
      }
      await _populatePreviewsInScaffold(_pathToPreviews);

      process.stdin.writeln(
        DaemonRequest.hotReload(appId: daemon.appId!).encode(),
      );
    });

    await process.exitCode;
  }
}
