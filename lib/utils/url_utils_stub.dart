// lib/utils/url_utils_stub.dart
// Fallback para plataformas no web.

class AnchorElement {
  String href = '';
  String target = '';
  String rel = '';
  void click() {}
  void remove() {}
}

class Document {
  Body? body;
  dynamic createElement(String tag) => AnchorElement();
}

class Body {
  void append(dynamic element) {}
}

class Event {
  Event(String type);
}

class Window {
  void dispatchEvent(Event event) {}
}

final document = Document();
final window = Window();
