import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../config/theme.dart';
import '../widgets/custom_header.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  Timer? _debounce;

  final String _apiKey = ApiKeys.groq;
  static const String _apiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';
  static const Duration _requestTimeout = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: 'Hi! I\'m your AI nutrition & fitness assistant. Ask me anything about diet, workouts, or healthy living!',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // No-op: debounce is just to prevent rapid submissions.
      // Actual send is triggered by button/onSubmitted.
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _debounce?.cancel();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
      _isSending = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await _getAiResponseWithRetry(text);
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
        _isSending = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Sorry, I couldn\'t process your request. Please try again.',
          isUser: false,
        ));
        _isLoading = false;
        _isSending = false;
      });
    }
    _scrollToBottom();
  }

  Future<String> _getAiResponseWithRetry(String message, {int retries = 2}) async {
    for (int i = 0; i <= retries; i++) {
      try {
        return await _getAiResponse(message);
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('429') && i < retries) {
          await Future.delayed(Duration(seconds: (i + 1) * 2));
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Max retries exceeded');
  }

  Future<String> _getAiResponse(String message) async {
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': 'You are a friendly nutrition and fitness assistant for the FitSync AI app. '
            'Provide helpful, accurate advice about diet, nutrition, workouts, and healthy living. '
            'Keep responses concise (2-3 paragraphs max). Be encouraging and supportive.',
      },
    ];

    for (final msg in _messages) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text,
      });
    }
    messages.add({'role': 'user', 'content': message});

    final body = jsonEncode({
      'model': _model,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 500,
    });

    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: body,
        )
        .timeout(_requestTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices']?[0]?['message']?['content'] as String? ?? 'No response';
    }
    throw Exception('${response.statusCode}');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
          CustomHeader(
            title: 'AI Assistant',
            showBack: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _messages.clear();
                    _messages.add(ChatMessage(
                      text: 'Hi! I\'m your AI nutrition & fitness assistant. Ask me anything!',
                      isUser: false,
                    ));
                  });
                },
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 48),
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(width: 12),
                        Text('Thinking...', style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }
                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: _onTextChanged,
                    decoration: InputDecoration(
                      hintText: 'Ask about nutrition, workouts...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppTheme.indigo200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppTheme.indigo200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      filled: true,
                      fillColor: AppTheme.indigo50,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: message.isUser ? AppTheme.primaryColor : AppTheme.indigo100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.indigo200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: AppTheme.indigo600, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}
