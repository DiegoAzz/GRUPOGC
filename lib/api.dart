import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  static const url = String.fromEnvironment('API_URL',
      defaultValue: 'https://appzplay.online/grupocg/api/index.php');
  String token = '';
  Future<dynamic> call(String action, [Map<String, dynamic>? data]) async {
    if (url.isEmpty) {
      throw Exception(
          'Configura API_URL con la dirección HTTPS de tu servidor.');
    }
    final response = await http
        .post(Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty && token != 'cookie-session')
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'action': action, ...?data}))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 401) token = '';
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(body['error'] ?? 'Error del servidor');
    }
    return body['data'];
  }
}
