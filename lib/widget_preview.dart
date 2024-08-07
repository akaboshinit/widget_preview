// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// An [InheritedWidget] that propagates the current size of the
/// [WidgetPreviewScaffold].
///
/// This is needed when determining how to put constraints on previewed widgets
/// that would otherwise have infinite constraints.
class WidgetPreviewerWindowConstraints extends InheritedWidget {
  const WidgetPreviewerWindowConstraints({
    super.key,
    required super.child,
    required this.constraints,
  });

  final BoxConstraints constraints;

  static BoxConstraints getRootConstraints(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<WidgetPreviewerWindowConstraints>();
    assert(
      result != null,
      'No WidgetPreviewerWindowConstraints founds in context',
    );
    return result!.constraints;
  }

  @override
  bool updateShouldNotify(WidgetPreviewerWindowConstraints oldWidget) {
    return oldWidget.constraints != constraints;
  }
}

/// Annotation used to mark functions that return widget previews.
class Preview {
  const Preview();
}

class WidgetPreview extends StatelessWidget {
  const WidgetPreview({
    super.key,
    required this.child,
    this.name,
    this.width,
    this.height,
    this.textScaleFactor,
  });

  final String? name;
  final Widget child;
  final double? width;
  final double? height;
  final double? textScaleFactor;

  @override
  Widget build(BuildContext context) {
    final previewerConstraints =
        WidgetPreviewerWindowConstraints.getRootConstraints(context);

    final maxSizeConstraints = previewerConstraints.copyWith(
      minHeight: previewerConstraints.maxHeight / 2.0,
      maxHeight: previewerConstraints.maxHeight / 2.0,
    );

    Widget preview = Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey,
        ),
        color: Colors.blue,
      ),
      child: _WidgetPreviewWrapper(
        previewerConstraints: maxSizeConstraints,
        child: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
    );

    var mediaQueryData = MediaQuery.of(context);

    if (textScaleFactor != null) {
      mediaQueryData = mediaQueryData.copyWith(
        textScaler: TextScaler.linear(textScaleFactor!),
      );
    }

    if (width != null || height != null) {
      mediaQueryData = mediaQueryData.copyWith(
        size: Size(width ?? mediaQueryData.size.width,
            height ?? mediaQueryData.size.height),
      );
    }

    preview = MediaQuery(data: mediaQueryData, child: preview);

    if (name != null) {
      preview = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          preview,
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8.0,
        horizontal: 16.0,
      ),
      child: preview,
    );
  }
}

/// Wrapper applying a custom render object to force constraints on
/// unconstrained widgets.
class _WidgetPreviewWrapper extends SingleChildRenderObjectWidget {
  const _WidgetPreviewWrapper({
    super.child,
    required this.previewerConstraints,
  });

  /// The size of the previewer render surface.
  final BoxConstraints previewerConstraints;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _WidgetPreviewWrapperBox(
      previewerConstraints: previewerConstraints,
      child: null,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _WidgetPreviewWrapperBox renderObject,
  ) {
    renderObject.setPreviewerConstraints(previewerConstraints);
  }
}

/// Custom render box that forces constraints onto unconstrained widgets.
class _WidgetPreviewWrapperBox extends RenderShiftedBox {
  _WidgetPreviewWrapperBox({
    required RenderBox? child,
    required BoxConstraints previewerConstraints,
  })  : _previewerConstraints = previewerConstraints,
        super(child);

  BoxConstraints _constraintOverride = const BoxConstraints();
  BoxConstraints _previewerConstraints;

  void setPreviewerConstraints(BoxConstraints previewerConstraints) {
    if (_previewerConstraints == previewerConstraints) {
      return;
    }
    _previewerConstraints = previewerConstraints;
    markNeedsLayout();
  }

  @override
  void layout(
    Constraints constraints, {
    bool parentUsesSize = false,
  }) {
    if (child != null && constraints is BoxConstraints) {
      double minInstrinsicHeight;
      try {
        minInstrinsicHeight = child!.getMinIntrinsicHeight(
          constraints.maxWidth,
        );
      } on Object {
        minInstrinsicHeight = 0.0;
      }
      // Determine if the previewed widget is vertically constrained. If the
      // widget has a minimum intrinsic height of zero given the widget's max
      // width, it has an unconstrained height and will cause an overflow in
      // the previewer. In this case, apply finite constraints (e.g., the
      // constraints for the root of the previewer). Otherwise, use the
      // widget's actual constraints.
      _constraintOverride = minInstrinsicHeight == 0
          ? _previewerConstraints
          : const BoxConstraints();
    }
    super.layout(
      constraints,
      parentUsesSize: parentUsesSize,
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = Size.zero;
      return;
    }
    final updatedConstraints = _constraintOverride.enforce(constraints);
    child.layout(
      updatedConstraints,
      parentUsesSize: true,
    );
    size = constraints.constrain(child.size);
  }
}
