import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/custom_text_field.dart';

class ApiKeysConfigScreen extends StatefulWidget {
  const ApiKeysConfigScreen({super.key});

  @override
  State<ApiKeysConfigScreen> createState() => _ApiKeysConfigScreenState();
}

class _ApiKeysConfigScreenState extends State<ApiKeysConfigScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers for WhatsApp API
  final _whatsappTokenCtrl = TextEditingController();
  final _whatsappPhoneIdCtrl = TextEditingController();
  final _whatsappWabaIdCtrl = TextEditingController();

  // Controllers for Resend API
  final _resendApiKeyCtrl = TextEditingController();

  // Controllers for AI
  final _chatgptApiKeyCtrl = TextEditingController();

  // Pre-established configuration state toggles
  bool _useDefaultWhatsApp = true;
  bool _useDefaultResend = true;

  // Visibility state map for secret keys
  final Map<String, bool> _obscureFields = {};

  @override
  void initState() {
    super.initState();
    _fetchSecrets();
  }

  @override
  void dispose() {
    _whatsappTokenCtrl.dispose();
    _whatsappPhoneIdCtrl.dispose();
    _whatsappWabaIdCtrl.dispose();
    _resendApiKeyCtrl.dispose();
    _chatgptApiKeyCtrl.dispose();
    super.dispose();
  }

  bool _isObscured(String fieldKey) {
    return _obscureFields[fieldKey] ?? true;
  }

  void _toggleObscure(String fieldKey) {
    setState(() {
      _obscureFields[fieldKey] = !_isObscured(fieldKey);
    });
  }

  Future<void> _fetchSecrets() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('Secrets')
          .select();

      // Reset defaults to true initially before loading from DB
      _useDefaultWhatsApp = true;
      _useDefaultResend = true;

      for (var row in response) {
        final key = row['key'] as String;
        final val = row['value'] as String? ?? '';

        switch (key) {
          case 'whatsapp_token':
            _whatsappTokenCtrl.text = val;
            break;
          case 'whatsapp_phone_number_id':
            _whatsappPhoneIdCtrl.text = val;
            break;
          case 'whatsapp_waba_id':
            _whatsappWabaIdCtrl.text = val;
            break;
          case 'resend_api_key':
            _resendApiKeyCtrl.text = val;
            break;
          case 'whatsapp_use_default':
            _useDefaultWhatsApp = val == 'true';
            break;
          case 'resend_use_default':
            _useDefaultResend = val == 'true';
            break;
          case 'chatgpt_api_key':
            _chatgptApiKeyCtrl.text = val;
            break;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar secretos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSecrets() async {
    setState(() => _isSaving = true);
    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      
      final secrets = [
        {
          'key': 'whatsapp_use_default',
          'value': _useDefaultWhatsApp ? 'true' : 'false',
          'description': 'WhatsApp API - Usar preestablecida de la plataforma',
          'updated_at': nowStr,
        },
        {
          'key': 'whatsapp_token',
          'value': _whatsappTokenCtrl.text.trim(),
          'description': 'WhatsApp API - Access Token',
          'updated_at': nowStr,
        },
        {
          'key': 'whatsapp_phone_number_id',
          'value': _whatsappPhoneIdCtrl.text.trim(),
          'description': 'WhatsApp API - Phone Number ID',
          'updated_at': nowStr,
        },
        {
          'key': 'whatsapp_waba_id',
          'value': _whatsappWabaIdCtrl.text.trim(),
          'description': 'WhatsApp API - WhatsApp Business Account ID',
          'updated_at': nowStr,
        },
        {
          'key': 'resend_use_default',
          'value': _useDefaultResend ? 'true' : 'false',
          'description': 'Resend - Usar preestablecida de la plataforma',
          'updated_at': nowStr,
        },
        {
          'key': 'resend_api_key',
          'value': _resendApiKeyCtrl.text.trim(),
          'description': 'Resend - API Key',
          'updated_at': nowStr,
        },
        {
          'key': 'chatgpt_api_key',
          'value': _chatgptApiKeyCtrl.text.trim(),
          'description': 'ChatGPT - API Key',
          'updated_at': nowStr,
        },
      ];

      await Supabase.instance.client
          .from('Secrets')
          .upsert(secrets);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración de APIs guardada exitosamente.'),
            backgroundColor: Colors.black,
          ),
        );
        _fetchSecrets();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar configuración: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 20),
          _buildWhatsAppCard(),
          const SizedBox(height: 16),
          _buildResendCard(),
          const SizedBox(height: 16),
          _buildAiCard(),
          const SizedBox(height: 30),
          _buildActionButtons(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key, color: Colors.black87, size: 20),
              SizedBox(width: 8),
              Text(
                'Credenciales y APIs',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Configura de forma segura los secretos de WhatsApp, Resend e Inteligencia Artificial.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSecretTextField({
    required TextEditingController controller,
    required String label,
    required String fieldKey,
    required IconData prefixIcon,
  }) {
    final obscured = _isObscured(fieldKey);
    return CustomTextField(
      controller: controller,
      label: label,
      prefixIcon: prefixIcon,
      obscureText: obscured,
      suffixIcon: IconButton(
        icon: Icon(
          obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: Colors.black54,
        ),
        onPressed: () => _toggleObscure(fieldKey),
      ),
    );
  }

  Widget _buildWhatsAppCard() {
    return _buildCardContainer(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('WhatsApp API', Icons.chat_bubble_outline),
            Row(
              children: [
                const Text(
                  'Usar preestablecida',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _useDefaultWhatsApp,
                  activeColor: Colors.black,
                  onChanged: (val) {
                    setState(() {
                      _useDefaultWhatsApp = val;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        const Text(
          'Claves para envíos automatizados de mensajes, confirmaciones y recordatorios por WhatsApp.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),
        if (!_useDefaultWhatsApp) ...[
          _buildSecretTextField(
            controller: _whatsappTokenCtrl,
            label: 'WhatsApp Access Token (Token de Acceso)',
            fieldKey: 'wa_token',
            prefixIcon: Icons.security_outlined,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _whatsappPhoneIdCtrl,
            label: 'ID de Número de Teléfono (Phone Number ID)',
            prefixIcon: Icons.phone_android_outlined,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _whatsappWabaIdCtrl,
            label: 'ID de Cuenta Business (WABA ID)',
            prefixIcon: Icons.business_center_outlined,
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.black54, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Utilizando la configuración y número oficial preestablecido de la plataforma.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResendCard() {
    return _buildCardContainer(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Resend Email API', Icons.mail_outline),
            Row(
              children: [
                const Text(
                  'Usar preestablecida',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _useDefaultResend,
                  activeColor: Colors.black,
                  onChanged: (val) {
                    setState(() {
                      _useDefaultResend = val;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        const Text(
          'Configura la API Key de Resend para notificaciones automáticas vía correo electrónico.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),
        if (!_useDefaultResend) ...[
          _buildSecretTextField(
            controller: _resendApiKeyCtrl,
            label: 'Resend API Key',
            fieldKey: 'resend_key',
            prefixIcon: Icons.mark_as_unread_outlined,
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.black54, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Utilizando el correo y dominio oficial preestablecido de la plataforma.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAiCard() {
    return _buildCardContainer(
      children: [
        _buildSectionHeader('Inteligencia Artificial', Icons.psychology_outlined),
        const Text(
          'Configura tu llave para usar el modelo de lenguaje avanzado de OpenAI (ChatGPT).',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),
        _buildSecretTextField(
          controller: _chatgptApiKeyCtrl,
          label: 'ChatGPT (OpenAI) API Key',
          fieldKey: 'chatgpt_key',
          prefixIcon: Icons.api_outlined,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveSecrets,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Guardar Cambios',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}
