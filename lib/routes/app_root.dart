import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/design/design_screen.dart';
import '../utils/web_js.dart';

/// Root widget that resolves special top-level routes (e.g. `/design` on web).
class AppRoot extends StatelessWidget {
  final Widget child;

  const AppRoot({super.key, required this.child});

  static bool isDesignRoute() {
    if (!kIsWeb) return false;
    final path = getWebPathname();
    if (path == null) return false;
    return isDesignPublicPath(path);
  }

  @override
  Widget build(BuildContext context) {
    if (isDesignRoute()) {
      return const DesignScreen();
    }
    return child;
  }
}

/// Whether [pathname] is the public design system route.
bool isDesignPublicPath(String pathname) {
  final segment = pathname
      .replaceAll(RegExp(r'^/+|/+$'), '')
      .split('/')
      .firstWhere((s) => s.isNotEmpty, orElse: () => '');
  return segment == 'design';
}
