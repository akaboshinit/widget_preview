// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore: prefer_relative_imports, this won't be a relative import in the preview environment.
import 'package:widget_preview/src/environment/widget_preview_scaffold.dart';

// ignore: uri_does_not_exist, will be generated.
import 'generated_preview.dart';

Future<void> main() async {
  // ignore: undefined_identifier, will be present in generated_preview.dart.
  await mainImpl(previewsProvider: previews);
}
