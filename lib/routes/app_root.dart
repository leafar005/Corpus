import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/design/design_screen.dart';
import '../screens/profile/collection_shelf_screen.dart';
import '../utils/web_js.dart';

final RegExp _trimSlashesRegex = RegExp(r'^/+|/+$');

/// Root widget that resolves special top-level routes (e.g. `/design` on web).
class AppRoot extends StatefulWidget {
  final Widget child;

  const AppRoot({super.key, required this.child});

  static bool isDesignRoute() {
    if (!kIsWeb || !kDebugMode) return false;
    final path = getWebPathname();
    if (path == null) return false;
    return isDesignPublicPath(path);
  }

  static bool isPrivateCollectionRoute() {
    if (!kIsWeb || !kDebugMode) return false;
    final path = getWebPathname();
    if (path == null) return false;
    return isPrivateCollectionPublicPath(path);
  }

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _dispatchedReady = false;

  void _scheduleCorpusReadyOnce() {
    if (_dispatchedReady) return;
    _dispatchedReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => dispatchCorpusReady());
  }

  @override
  Widget build(BuildContext context) {
    if (AppRoot.isDesignRoute()) {
      _scheduleCorpusReadyOnce();
      return const DesignScreen();
    }
    if (AppRoot.isPrivateCollectionRoute()) {
      _scheduleCorpusReadyOnce();
      return const CollectionShelfScreen();
    }
    return widget.child;
  }
}

/// Whether [pathname] is the public design system route.
bool isDesignPublicPath(String pathname) {
  final segment = pathname
      .replaceAll(_trimSlashesRegex, '')
      .split('/')
      .firstWhere((s) => s.isNotEmpty, orElse: () => '');
  return segment == 'design';
}

/// Whether [pathname] is the debug shelf route (`/private/collection`).
bool isPrivateCollectionPublicPath(String pathname) {
  final segments = pathname
      .replaceAll(_trimSlashesRegex, '')
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();
  return segments.length == 2 &&
      segments[0] == 'private' &&
      segments[1] == 'collection';
}
