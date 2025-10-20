// lib/chatbot_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:pharmaapp/api_service.dart';
import 'package:pharmaapp/auth_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<_Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  late final ApiService _apiService;
  final String _botName = 'PharmPal';

  @override
  void initState() {
    super.initState();
    
    // Initialize ApiService with AuthService
    _apiService = ApiService(AuthService());
    
    // Initial greeting
    _addMessage(_Message(
      id: const Uuid().v4(),
      text: 'Hello! How can I help you with the inventory today?',
      isUser: false,
    ));
  }

  void _addMessage(_Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Add user message
    _addMessage(_Message(id: const Uuid().v4(), text: text, isUser: true));
    _controller.clear();

    // Add temporary bot "typing" message
    final typingMessage = _Message(
      id: const Uuid().v4(),
      text: '...',
      isUser: false,
      isTyping: true,
    );
    _addMessage(typingMessage);

    try {
      final botResponse = await _apiService.askChatbot(text);

      setState(() {
        _messages.removeWhere((msg) => msg.isTyping); // remove typing indicator
      });

      _addMessage(_Message(id: const Uuid().v4(), text: botResponse, isUser: false));
    } catch (e) {
      setState(() {
        _messages.removeWhere((msg) => msg.isTyping);
      });

      _addMessage(_Message(
        id: const Uuid().v4(),
        text: 'Sorry, an error occurred: $e',
        isUser: false,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PharmPal Assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment:
                      message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: message.isUser ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      message.isTyping ? 'Typing...' : message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _handleSend,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple message model
class _Message {
  final String id;
  final String text;
  final bool isUser;
  final bool isTyping;

  _Message({
    required this.id,
    required this.text,
    required this.isUser,
    this.isTyping = false,
  });
}