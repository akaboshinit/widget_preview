// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

const String widgetPreviewScaffold = '''
import 'package:flutter/material.dart';
import 'package:widget_preview/widget_preview.dart';

import 'generated_preview.dart';

void main() {
  runApp(const WidgetPreviewScaffold());
}

class WidgetPreviewScaffold extends StatelessWidget {
  const WidgetPreviewScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return WidgetPreviewerWindowConstraints(
              constraints: constraints,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final preview in previews()) ...[
                      preview,
                    ]
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
''';
