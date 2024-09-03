// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

const String widgetPreviewScaffold = '''
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:widget_preview/src/environment/widget_preview.dart';

import 'generated_preview.dart';

void main() {
  runApp(const WidgetPreviewScaffold());
}

class WidgetPreviewScaffold extends StatelessWidget {
  const WidgetPreviewScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final previewList = previews();
    Widget previewView;
    if (previewList.isEmpty) {
      previewView = Column(
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
        child: previewView,
      ),
    );
  }
}
''';
