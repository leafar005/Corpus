// lib/utils/url_utils_stub.dart
// Fallback para plataformas no web.

import 'dart:async';

class AnchorElement {
  String href = '';
  String target = '';
  String rel = '';
  void click() {}
  void remove() {}
}

class Location {
  String pathname = '/';
  String search = '';
}

class History {
  dynamic state;
  void pushState(dynamic state, String title, String url) {}
  void replaceState(dynamic state, String title, String url) {}
  void back() {}
}

class PopStateEvent {
  dynamic state;
  PopStateEvent(String type);
}

class Window {
  Location location = Location();
  History history = History();
  final Stream<PopStateEvent> onPopState = const Stream.empty();

  void dispatchEvent(Event event) {}
}

class Event {
  Event(String type);
}

class Body {
  void append(dynamic element) {}
}

class Document {
  Body? body;
  dynamic createElement(String tag) => AnchorElement();
}

final document = Document();
final window = Window();
