// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:device_frame/device_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'src/buttons.dart';

/// An [InheritedWidget] that propagates the current size of the
/// WidgetPreviewScaffold.
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

class VerticalSpacer extends StatelessWidget {
  const VerticalSpacer();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 10,
    );
  }
}

class InteractiveViewerWrapper extends StatelessWidget {
  const InteractiveViewerWrapper({
    super.key,
    required this.child,
    required this.transformationController,
  });

  final Widget child;
  final TransformationController transformationController;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: transformationController,
      scaleEnabled: false,
      child: child,
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.transformationController});

  final TransformationController transformationController;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WidgetPreviewIconButton(
          tooltip: 'Zoom in',
          onPressed: _zoomIn,
          icon: Icons.zoom_in,
        ),
        const SizedBox(
          width: 10,
        ),
        WidgetPreviewIconButton(
          tooltip: 'Zoom out',
          onPressed: _zoomOut,
          icon: Icons.zoom_out,
        ),
        const SizedBox(
          width: 10,
        ),
        WidgetPreviewIconButton(
          tooltip: 'Reset zoom',
          onPressed: _reset,
          icon: Icons.refresh,
        ),
      ],
    );
  }

  void _zoomIn() {
    transformationController.value = Matrix4.copy(
      transformationController.value,
    ).scaled(1.1);
  }

  void _zoomOut() {
    final updated = Matrix4.copy(
      transformationController.value,
    ).scaled(0.9);

    // Don't allow for zooming out past the original size of the widget.
    // Assumes scaling is evenly applied to the entire matrix.
    if (updated.entry(0, 0) < 1.0) {
      updated.setIdentity();
    }

    transformationController.value = updated;
  }

  void _reset() {
    transformationController.value = Matrix4.identity();
  }
}

class _OrientationButton extends StatelessWidget {
  final Orientation orientation;
  final void Function() onPressed;

  const _OrientationButton({
    required this.orientation,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return WidgetPreviewIconButton(
      tooltip: 'Rotate to ${orientation.rotate.name}',
      onPressed: onPressed,
      icon: orientation == Orientation.portrait
          ? Icons.landscape
          : Icons.portrait,
    );
  }
}

class WidgetPreview extends StatefulWidget {
  const WidgetPreview({
    super.key,
    required this.child,
    this.name,
    this.width,
    this.height,
    this.device,
    this.orientation,
    this.textScaleFactor,
  });

  final String? name;
  final Widget child;
  final double? width;
  final double? height;
  final DeviceInfo? device;
  final Orientation? orientation;
  final double? textScaleFactor;

  @override
  State<WidgetPreview> createState() => _WidgetPreviewState();
}

class _WidgetPreviewState extends State<WidgetPreview> {
  final transformationController = TransformationController();
  final deviceOrientation = ValueNotifier<Orientation>(Orientation.portrait);

  @override
  void initState() {
    super.initState();
    if (widget.orientation case var orientation?) {
      deviceOrientation.value = orientation;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: deviceOrientation,
      builder: (context, orientation, _) {
        final previewerConstraints =
            WidgetPreviewerWindowConstraints.getRootConstraints(context);

        final maxSizeConstraints = previewerConstraints.copyWith(
          minHeight: previewerConstraints.maxHeight / 2.0,
          maxHeight: previewerConstraints.maxHeight / 2.0,
        );

        Widget preview = _WidgetPreviewWrapper(
          previewerConstraints: maxSizeConstraints,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: widget.child,
          ),
        );

        if (widget.device case var device?) {
          preview = DeviceFrame(
            device: device,
            orientation: orientation,
            screen: preview,
          );

          // Don't let the device frame get too large.
          if (device.frameSize.height > maxSizeConstraints.biggest.height ||
              device.frameSize.width > maxSizeConstraints.biggest.width) {
            preview = SizedBox.fromSize(
              size: maxSizeConstraints.constrain(device.frameSize),
              child: preview,
            );
          }
        }

        var mediaQueryData = MediaQuery.of(context);

        if (widget.textScaleFactor != null) {
          mediaQueryData = mediaQueryData.copyWith(
            textScaler: TextScaler.linear(widget.textScaleFactor!),
          );
        }

        var size = Size(widget.width ?? mediaQueryData.size.width,
            widget.height ?? mediaQueryData.size.height);

        if (widget.width != null || widget.height != null) {
          mediaQueryData = mediaQueryData.copyWith(
            size: size,
          );
        }

        preview = MediaQuery(data: mediaQueryData, child: preview);

        preview = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.name != null) ...[
              Text(
                widget.name!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const VerticalSpacer(),
            ],
            InteractiveViewerWrapper(
              child: preview,
              transformationController: transformationController,
            ),
            const VerticalSpacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ZoomControls(
                  transformationController: transformationController,
                ),
                const SizedBox(
                  width: 30,
                ),
                _OrientationButton(
                  orientation: orientation,
                  onPressed: () {
                    deviceOrientation.value = deviceOrientation.value.rotate;
                  },
                ),
              ],
            ),
          ],
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 16.0,
            ),
            child: preview,
          ),
        );
      },
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

extension OrientationUtils on Orientation {
  Orientation get rotate => this == Orientation.portrait
      ? Orientation.landscape
      : Orientation.portrait;
}
