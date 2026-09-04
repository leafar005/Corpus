import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/design/design_screen.dart';
import '../screens/profile/collection_shelf_screen.dart';
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

  static bool isPrivateCollectionRoute() {
    if (!kIsWeb) return false;
    final path = getWebPathname();
    if (path == null) return false;
    return isPrivateCollectionPublicPath(path);
  }

  @override
  Widget build(BuildContext context) {
    if (isDesignRoute()) {
      return const DesignScreen();
    }
    if (isPrivateCollectionRoute()) {
      return const CollectionShelfScreen();
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

/// Whether [pathname] is the debug shelf route (`/private/collection`).
bool isPrivateCollectionPublicPath(String pathname) {
  final segments = pathname
      .replaceAll(RegExp(r'^/+|/+$'), '')
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();
  return segments.length == 2 &&
      segments[0] == 'private' &&
      segments[1] == 'collection';
}
