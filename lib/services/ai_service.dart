import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AiService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  /// Retrieves the ChatGPT API Key dynamically from the Secrets table.
  static Future<String?> getChatGPTApiKey() async {
    try {
      final response = await Supabase.instance.client
          .from('Secrets')
          .select('value')
          .eq('key', 'chatgpt_api_key')
          .maybeSingle();
      
      if (response != null && response['value'] != null) {
        final key = response['value'].toString().trim();
        if (key.isNotEmpty) return key;
      }
      return null;
    } catch (e) {
      debugPrint('AiService: Error loading ChatGPT API key: $e');
      return null;
    }
  }

  /// Sends a message to the ChatGPT API and returns the AI's response.
  static Future<({bool success, String message})> sendMessage({
    required List<Map<String, String>> messages,
  }) async {
    try {
      final apiKey = await getChatGPTApiKey();
      if (apiKey == null) {
        return (success: false, message: 'No se encontró la API Key de OpenAI configurada.');
      }

      final String targetUrl = kIsWeb
          ? 'https://corsproxy.io/?https://api.openai.com/v1/chat/completions'
          : _baseUrl;

      final body = <String, dynamic>{
        // Using gpt-4o-mini as it is much faster, cheaper, and standard for new integrations
        'model': 'gpt-4o-mini',
        'messages': messages,
        'temperature': 0.7,
      };

      final encodedBody = jsonEncode(body);
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

      final List<String> urlsToTry = kIsWeb
          ? [
              'https://corsproxy.io/?https://api.openai.com/v1/chat/completions',
              _baseUrl,
            ]
          : [_baseUrl];

      String lastError = '';
      for (final url in urlsToTry) {
        try {
          final response = await http.post(
            Uri.parse(url),
            headers: headers,
            body: encodedBody,
          );
          
          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            final reply = data['choices'][0]['message']['content'].toString().trim();
            return (success: true, message: reply);
          } else {
            final errorData = jsonDecode(response.body);
            lastError = 'HTTP ${response.statusCode}: ${errorData['error']?['message'] ?? response.body}';
          }
        } catch (err) {
          lastError = '$err';
        }
      }

      return (success: false, message: lastError);
    } catch (e) {
      debugPrint('AiService: Exception during sendMessage: $e');
      return (success: false, message: 'Excepción: $e');
    }
  }
}
