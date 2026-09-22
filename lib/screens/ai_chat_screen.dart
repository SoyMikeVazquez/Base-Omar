import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/ai_service.dart';
import 'api_keys_config_screen.dart';

class AiChatScreen extends StatefulWidget {
  final String dbContext;
  
  const AiChatScreen({super.key, this.dbContext = ''});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  
  bool _isLoadingKey = true;
  bool _hasKey = false;
  bool _isTyping = false;

  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'system',
      'content': 'Eres un asistente inteligente para el sistema de Omar Studio. Eres educado, profesional y conciso. Ayudas al administrador a analizar datos, escribir textos, o cualquier tarea relacionada con el negocio de la barbería/salón.\n\nAquí tienes el estado actual de la base de datos para que puedas responder preguntas precisas sobre el día de hoy:\n${widget.dbContext}'
    });
    _messages.add({
      'role': 'assistant',
      'content': '¡Hola! Soy tu asistente de Inteligencia Artificial. Tengo acceso a los datos actuales de tu negocio. ¿En qué te puedo ayudar hoy?'
    });
    _checkApiKey();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkApiKey() async {
    setState(() => _isLoadingKey = true);
    final key = await AiService.getChatGPTApiKey();
    if (mounted) {
      setState(() {
        _hasKey = key != null && key.isNotEmpty;
        _isLoadingKey = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isTyping = true;
    });
    _messageCtrl.clear();
    _scrollToBottom();

    // Send to OpenAI
    final result = await AiService.sendMessage(messages: _messages);

    if (mounted) {
      setState(() {
        _isTyping = false;
        if (result.success) {
          _messages.add({'role': 'assistant', 'content': result.message});
        } else {
          _messages.add({
            'role': 'assistant',
            'content': 'Error: ${result.message}\nPor favor, verifica tu conexión o API Key.'
          });
        }
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Asistente IA', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingKey) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }

    if (!_hasKey) {
      return _buildNoKeyPrompt();
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              if (msg['role'] == 'system') return const SizedBox.shrink();

              final isUser = msg['role'] == 'user';
              return _buildChatBubble(msg['content'] ?? '', isUser);
            },
          ),
        ),
        if (_isTyping)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Text('El asistente está escribiendo...', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.black : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
          border: isUser ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(
        bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageCtrl,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoKeyPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Falta la API Key',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Para usar el Asistente Inteligente necesitas configurar tu llave de OpenAI (ChatGPT) en el panel de configuración de la plataforma.',
              style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Scaffold(
                    backgroundColor: Colors.white,
                    appBar: AppBar(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    body: const SafeArea(child: ApiKeysConfigScreen()),
                  )),
                );
                // Recheck key when returning
                _checkApiKey();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Configurar API Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
