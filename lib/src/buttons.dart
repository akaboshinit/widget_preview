import 'package:flutter/material.dart';

class WidgetPreviewIconButton extends StatelessWidget {
  const WidgetPreviewIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final void Function() onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Ink(
        decoration: const ShapeDecoration(
          shape: CircleBorder(),
          color: Colors.lightBlue,
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            color: Colors.white,
            icon,
          ),
        ),
      ),
    );
  }
}
