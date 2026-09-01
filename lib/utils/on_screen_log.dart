import 'package:flutter/foundation.dart';

class OnScreenLog {
  static final ValueNotifier<List<String>> lines = ValueNotifier([]);

  static void add(String msg) {
    final next = [...lines.value, msg];
    OnScreenLog.lines.value = next.length > 5
        ? next.sublist(next.length - 5)
        : next;
  }
}
