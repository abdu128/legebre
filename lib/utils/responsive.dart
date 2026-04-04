import 'package:flutter/material.dart';

/// Max content width for forms and detail screens on large displays.
const double kFormMaxWidth = 600.0;

/// Max content width for grid / list screens on large displays.
const double kContentMaxWidth = 1360.0;

/// Wraps [child] in a centered, width‑constrained box so the content
/// doesn't stretch edge‑to‑edge on tablets / desktops.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Returns a responsive cross‑axis count for grids based on the available width.
int responsiveCrossAxisCount(double width, {double itemMinWidth = 180}) {
  final count = (width / itemMinWidth).floor();
  return count.clamp(2, 6);
}
