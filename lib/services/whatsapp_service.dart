import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class WhatsAppService {
  /// Cleans and formats phone numbers for WhatsApp API.
  /// - Removes all non-digit characters.
  /// - If the number is 10 digits, prepends the Mexico country code and mobile prefix '521'.
  /// - If the number is 12 digits and starts with '52', replaces the '52' prefix with '521' for mobile numbers.
  static String formatPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 10) {
      return '521$cleaned';
    }
    if (cleaned.startsWith('52') && cleaned.length == 12) {
      return '521${cleaned.substring(2)}';
    }
    return cleaned;
  }

  /// Retrieves WhatsApp API credentials dynamically from the Supabase Secrets table.
  /// If using platform defaults, or if not configured, uses the system pre-established credentials.
  static Future<Map<String, String>> getWhatsAppSecrets() async {
    final Map<String, String> secrets = {};
    try {
      final response = await Supabase.instance.client
          .from('Secrets')
          .select('key, value')
          .inFilter('key', ['whatsapp_token', 'whatsapp_phone_number_id', 'whatsapp_use_default']);
      
      String? token;
      String? phoneId;
      bool useDefault = true;

      for (var row in response) {
        final key = row['key'] as String;
        final val = row['value'] as String? ?? '';
        if (key == 'whatsapp_use_default') {
          useDefault = val == 'true';
        } else if (key == 'whatsapp_token') {
          token = val;
        } else if (key == 'whatsapp_phone_number_id') {
          phoneId = val;
        }
      }

      if (useDefault || token == null || token.trim().isEmpty || phoneId == null || phoneId.trim().isEmpty) {
        // No hardcoded fallbacks for security (github scanning)
        secrets['whatsapp_token'] = '';
        secrets['whatsapp_phone_number_id'] = '';
      } else {
        secrets['whatsapp_token'] = token;
        secrets['whatsapp_phone_number_id'] = phoneId;
      }
    } catch (e) {
      debugPrint('WhatsAppService: Error fetching secrets: $e');
      // No hardcoded fallbacks for security
      secrets['whatsapp_token'] = '';
      secrets['whatsapp_phone_number_id'] = '';
    }
    return secrets;
  }

  /// Sends a beautiful, structured Purchase Ticket via WhatsApp
  static Future<bool> sendPurchaseTicketWhatsApp({
    required String clientPhone,
    required String clientName,
    required double total,
    required String sucursal,
    required String formaPago,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      if (clientPhone.trim().isEmpty) {
        debugPrint('WhatsAppService: Phone number is empty, skipping send.');
        return false;
      }

      // 1. Get WhatsApp configurations
      final secrets = await getWhatsAppSecrets();
      final token = secrets['whatsapp_token'];
      final phoneId = secrets['whatsapp_phone_number_id'];

      if (token == null || token.trim().isEmpty || phoneId == null || phoneId.trim().isEmpty) {
        debugPrint('WhatsAppService: WhatsApp credentials are not configured in the Secrets table.');
        return false;
      }

      // 2. Fetch business name dynamically from General table
      String companyName = 'Omar Studio';
      try {
        final generalData = await Supabase.instance.client
            .from('General')
            .select('NombreDeLaEmpresa')
            .limit(1)
            .maybeSingle();
        if (generalData != null && generalData['NombreDeLaEmpresa'] != null) {
          final dbName = generalData['NombreDeLaEmpresa'].toString().trim();
          if (dbName.isNotEmpty) {
            companyName = dbName;
          }
        }
      } catch (e) {
        debugPrint('WhatsAppService: Error fetching company name: $e');
      }

      final dateStr = DateTime.now().toLocal().toString().substring(0, 16);
      final formattedPhone = formatPhone(clientPhone);

      // 3. Build text list of purchased items
      final StringBuffer itemsText = StringBuffer();
      for (var item in items) {
        final name = item['name'] ?? item['nombre'] ?? 'Concepto';
        final price = double.tryParse((item['price'] ?? item['precio'] ?? '0').toString()) ?? 0.0;
        final qty = int.tryParse((item['qty'] ?? item['cantidad'] ?? '1').toString()) ?? 1;
        final subtotal = price * qty;
        itemsText.writeln('• *$name* x$qty - \$${subtotal.toStringAsFixed(2)}');
      }

      // 4. Format the final ticket message (using WhatsApp markdown styling)
      final messageText = 
          '*TICKET DE COMPRA - $companyName* 🧾\n\n'
          '¡Gracias por tu compra, ${clientName.isNotEmpty ? clientName : 'Cliente'}! 👋\n\n'
          '*Detalles de la Transacción:*\n'
          '• *Sucursal:* $sucursal\n'
          '• *Fecha:* $dateStr\n'
          '• *Forma de Pago:* $formaPago\n\n'
          '*Detalles de los artículos:*\n'
          '${itemsText.toString()}'
          '---------------------------\n'
          '*Total Pagado: \$${total.toStringAsFixed(2)}*\n\n'
          '¡Esperamos verte pronto de nuevo!';

      // 5. Send POST request to WhatsApp Graph API
      final uri = Uri.parse('https://graph.facebook.com/v17.0/$phoneId/messages');
      final body = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": formattedPhone,
        "type": "text",
        "text": {
          "preview_url": false,
          "body": messageText,
        }
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('WhatsAppService: Ticket successfully sent to $formattedPhone');
        return true;
      } else {
        debugPrint('WhatsAppService: Failed to send ticket (status: ${response.statusCode}) - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('WhatsAppService: Exception during sendPurchaseTicketWhatsApp: $e');
      return false;
    }
  }
}
