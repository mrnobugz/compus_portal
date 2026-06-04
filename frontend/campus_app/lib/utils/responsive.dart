import 'package:flutter/material.dart';

enum ScreenSize { compact, medium, expanded }

class Responsive {
  static ScreenSize of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return ScreenSize.expanded;
    if (w >= 600) return ScreenSize.medium;
    return ScreenSize.compact;
  }

  static bool isCompact(BuildContext context) =>
      of(context) == ScreenSize.compact;

  static int gridColumns(BuildContext context, {int max = 4}) {
    switch (of(context)) {
      case ScreenSize.expanded:
        return max;
      case ScreenSize.medium:
        return max > 2 ? 3 : 2;
      case ScreenSize.compact:
        return 2;
    }
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.symmetric(
      horizontal: w >= 900 ? 32 : w >= 600 ? 24 : 16,
      vertical: 16,
    );
  }

  static double maxContentWidth(BuildContext context) {
    switch (of(context)) {
      case ScreenSize.expanded:
        return 1200;
      case ScreenSize.medium:
        return 800;
      case ScreenSize.compact:
        return double.infinity;
    }
  }

  static Widget constrained(Widget child, BuildContext context) {
    final maxW = maxContentWidth(context);
    if (maxW == double.infinity) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }
}
