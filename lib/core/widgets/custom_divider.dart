import 'package:flutter/material.dart';

enum DividerAxis { vertical, horizontal }

class CustomDivider extends StatelessWidget {
  final double height;
  final double thickness;
  final Color? color;
  final double indent;
  final double endIndent;
  final EdgeInsets padding;
  final DividerAxis dividerAxis;

  const CustomDivider({
    super.key,
    this.height = 1,
    this.thickness = 1.0,
    this.color,
    this.indent = 0,
    this.endIndent = 0,
    this.padding = EdgeInsets.zero,
    this.dividerAxis = DividerAxis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: dividerAxis == DividerAxis.vertical
          ? VerticalDivider(
              width: height,
              thickness: thickness,
              color:
                  color ??
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              indent: indent,
              endIndent: endIndent,
            )
          : Divider(
              height: height,
              thickness: thickness,
              color:
                  color ??
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              indent: indent,
              endIndent: endIndent,
            ),
    );
  }
}
