import 'package:http/http.dart' as http;

Future<bool> hasNetworkConnection() async {
  try {
    final response = await http
        .get(Uri.parse('https://www.google.com/generate_204'))
        .timeout(const Duration(seconds: 4));

    return response.statusCode >= 200 && response.statusCode < 400;
  } catch (_) {
    return false;
  }
}
