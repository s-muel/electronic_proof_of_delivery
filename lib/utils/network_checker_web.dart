import 'dart:html' as html;

Future<bool> hasNetworkConnection() async {
  return html.window.navigator.onLine ?? false;
}
