import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HelpAssistantScreen extends StatefulWidget {
  const HelpAssistantScreen({super.key});

  @override
  State<HelpAssistantScreen> createState() => _HelpAssistantScreenState();
}

class _HelpAssistantScreenState extends State<HelpAssistantScreen> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[
    _ChatMessage(
      isBot: true,
      text:
          'Hi! I\'m the Campus Portal assistant. Ask about login, notes, assignments, library, support, grades, or attendance.',
    ),
  ];

  static const _faq = {
    'login':
        'Use your username or email with your password on the login screen. New students can tap "Create an account" to register.',
    'register':
        'Tap "New student? Create an account" on the login page. You\'ll need your student ID, department, and course.',
    'notes':
        'Open the Notes tab to view course materials. Tap a note to read PDF/TXT in-app or download it.',
    'assignment':
        'Check the Tasks tab for assignments. Tap download to save files to your device.',
    'library':
        'From Home, tap Library to browse eBooks. Tap a book to download it for offline reading.',
    'book':
        'From Home, tap Library to browse eBooks. Tap a book to download it for offline reading.',
    'support':
        'Go to Home → Support to submit a ticket. Staff replies appear in the app and you get a notification.',
    'grade':
        'Open Home → Performance to view your scores and average percentage.',
    'performance':
        'Open Home → Performance to view your scores and average percentage.',
    'attendance':
        'Open Home → Attendance to see your session history and attendance rate.',
    'password':
        'Contact your administrator to reset your password. Admins can manage accounts at /admin/.',
    'group':
        'The Groups tab shows study groups matched to your department and course.',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(isBot: false, text: text));
      _messages.add(_ChatMessage(isBot: true, text: _reply(text)));
    });
  }

  String _reply(String input) {
    final lower = input.toLowerCase();
    for (final entry in _faq.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    if (lower.contains('hello') || lower.contains('hi')) {
      return 'Hello! How can I help you navigate the campus portal today?';
    }
    return 'I can help with login, registration, notes, assignments, library, support, grades, and attendance. Try asking about one of those topics, or use Support for personal issues.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Assistant'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                return Align(
                  alignment: msg.isBot
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isBot
                          ? Colors.grey.shade200
                          : AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(msg.text),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask a question…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
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

class _ChatMessage {
  final bool isBot;
  final String text;

  const _ChatMessage({required this.isBot, required this.text});
}
