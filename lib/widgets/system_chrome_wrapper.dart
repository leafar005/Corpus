import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/web_viewport_sync.dart';

/// Returns the edge-to-edge [SystemUiOverlayStyle] matching [brightness].
SystemUiOverlayStyle corpusSystemUiOverlayStyle(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}

/// Bridges CSS `env(safe-area-inset-*)` values into [MediaQueryData] on Web
/// without double-padding if the browser/engine already reports `viewPadding`.
MediaQueryData applyWebSafeAreaInsets(
  MediaQueryData mq,
  EdgeInsets webInsets,
) {
  if (webInsets == EdgeInsets.zero) return mq;

  final top = math.max(mq.viewPadding.top, webInsets.top);
  final right = math.max(mq.viewPadding.right, webInsets.right);
  final bottom = math.max(mq.viewPadding.bottom, webInsets.bottom);
  final left = math.max(mq.viewPadding.left, webInsets.left);

  final padTop = math.max(0.0, top - mq.viewInsets.top);
  final padRight = math.max(0.0, right - mq.viewInsets.right);
  final padBottom = math.max(0.0, bottom - mq.viewInsets.bottom);
  final padLeft = math.max(0.0, left - mq.viewInsets.left);

  return mq.copyWith(
    viewPadding: EdgeInsets.fromLTRB(left, top, right, bottom),
    padding: EdgeInsets.fromLTRB(padLeft, padTop, padRight, padBottom),
  );
}

/// Applies global edge-to-edge system UI overlay styles on native mobile and
/// bridges CSS safe-area insets + theme-color chrome syncing on Flutter Web.
class SystemChromeWrapper extends StatefulWidget {
  final Widget child;

  const SystemChromeWrapper({super.key, required this.child});

  @override
  State<SystemChromeWrapper> createState() => _SystemChromeWrapperState();
}

class _SystemChromeWrapperState extends State<SystemChromeWrapper>
    with WidgetsBindingObserver {
  EdgeInsets _webInsets = EdgeInsets.zero;
  Color? _lastSyncedBg;
  Brightness? _lastSyncedBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      _webInsets = getWebSafeAreaInsets();
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshWebInsets());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb) {
      final theme = Theme.of(context);
      if (theme.scaffoldBackgroundColor != _lastSyncedBg ||
          theme.brightness != _lastSyncedBrightness) {
        _lastSyncedBg = theme.scaffoldBackgroundColor;
        _lastSyncedBrightness = theme.brightness;
        syncWebThemeChrome(theme.scaffoldBackgroundColor, theme.brightness);
      }
    }
  }

  @override
  void didChangeMetrics() {
    if (kIsWeb) {
      _refreshWebInsets();
    }
  }

  void _refreshWebInsets() {
    if (!mounted) return;
    final next = getWebSafeAreaInsets();
    if (next != _webInsets) {
      setState(() {
        _webInsets = next;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget content = AnnotatedRegion<SystemUiOverlayStyle>(
      value: corpusSystemUiOverlayStyle(theme.brightness),
      child: widget.child,
    );

    if (kIsWeb && _webInsets != EdgeInsets.zero) {
      content = MediaQuery(
        data: applyWebSafeAreaInsets(MediaQuery.of(context), _webInsets),
        child: content,
      );
    }

    return content;
  }
}
