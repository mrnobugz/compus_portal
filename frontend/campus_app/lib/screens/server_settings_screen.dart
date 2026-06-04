import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback_banner.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _controller = TextEditingController(text: AppConfig.host);
  String? _feedback;
  FeedbackType? _feedbackType;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final host = _controller.text.trim();
    if (host.isEmpty) {
      setState(() {
        _feedback = 'Enter your server address';
        _feedbackType = FeedbackType.error;
      });
      return;
    }
    await AppConfig.saveHost(host);
    if (mounted) {
      showAppSnackBar(context, message: 'Server address saved', success: true);
      Navigator.pop(context, true);
    }
  }

  Future<void> _reset() async {
    await AppConfig.clearHostOverride();
    setState(() => _controller.text = AppConfig.host);
    if (mounted) {
      showAppSnackBar(context, message: 'Reset to default', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server settings'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Backend server address',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'On a physical phone, use your computer\'s LAN IP (not 10.0.2.2). '
              'Example: ${AppConfig.defaultPhysicalDeviceHint}',
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (_feedback != null && _feedbackType != null) ...[
              FeedbackBanner(
                message: _feedback!,
                type: _feedbackType!,
                onDismiss: () => setState(() => _feedback = null),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://192.168.1.10:8000',
                prefixIcon: Icon(Icons.dns),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Save'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _reset,
              child: const Text('Reset to default'),
            ),
          ],
        ),
      ),
    );
  }
}
