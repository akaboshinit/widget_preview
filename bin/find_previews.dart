// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:code_builder/code_builder.dart' as builder;
import 'package:dart_style/dart_style.dart';

void main(List<String> args) async {
  FileSystemEntity entity = Directory.current;
  if (args.isNotEmpty) {
    String arg = args.first;
    entity = FileSystemEntity.isDirectorySync(arg) ? Directory(arg) : File(arg);
  }

  var collection = AnalysisContextCollection(
      includedPaths: [entity.absolute.path],
      resourceProvider: PhysicalResourceProvider.INSTANCE);

  final previews = <({String path, String method})>[];

  for (var context in collection.contexts) {
    print('Analyzing ${context.contextRoot.root.path} ...');

    for (var filePath in context.contextRoot.analyzedFiles()) {
      if (!filePath.endsWith('.dart')) {
        continue;
      }

      final lib = context.currentSession.getParsedLibrary(filePath)
          as ParsedLibraryResult;
      for (final unit in lib.units) {
        for (final entity in unit.unit.childEntities) {
          if (entity is FunctionDeclaration &&
              !entity.name.toString().startsWith('_')) {
            bool foundPreview = false;
            for (final annotation in entity.metadata) {
              if (annotation.name.name == 'Preview') {
                // What happens if the annotation is applied multiple times?
                foundPreview = true;
                break;
              }
            }
            if (foundPreview) {
              print('Found preview!');
              print('File path: $filePath');
              print(Uri.file(filePath.toString()));
              print('Preview function: ${entity.name}');
              previews.add(
                (
                  path: Uri.file(filePath.toString()).toString(),
                  method: entity.name.toString(),
                ),
              );
            }
          }
        }
      }
    }
  }

  final lib = builder.Library(
    (b) => b.body.addAll(
      [
        builder.Directive.import(
          'package:preview_playground/preview_widget_wrapper.dart',
        ),
        builder.Method(
          (b) => b
            ..body = builder.literalList(
              [
                for (final preview in previews)
                  builder.refer(preview.method, preview.path).spread.call([]),
              ],
            ).code

            ..name = 'previews'
            ..returns = builder.refer('List<WidgetPreview>'),
        )
      ],
    ),
  );
  final emitter = builder.DartEmitter.scoped(useNullSafetySyntax: true);
  File(
    Platform.script.resolve('../.dart_tool/preview_scaffold/lib/generated_preview.dart').toFilePath(),
  ).writeAsStringSync(
    DartFormatter().format('${lib.accept(emitter)}'),
  );
}
