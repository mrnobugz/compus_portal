import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_password_field.dart';
import '../widgets/feedback_banner.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _feedback;
  FeedbackType? _feedbackType;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });

    final result = await ApiService.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (result['success'] == true) {
      showAppSnackBar(context, message: 'Password updated successfully', success: true);
      Navigator.pop(context, true);
    } else {
      setState(() {
        _feedback = result['error']?.toString() ?? 'Could not update password';
        _feedbackType = FeedbackType.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change password'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose a strong password with at least 6 characters.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              if (_feedback != null && _feedbackType != null) ...[
                FeedbackBanner(
                  message: _feedback!,
                  type: _feedbackType!,
                  onDismiss: () => setState(() => _feedback = null),
                ),
                const SizedBox(height: 16),
              ],
              AppPasswordField(
                controller: _currentController,
                label: 'Current password',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter current password' : null,
              ),
              const SizedBox(height: 14),
              AppPasswordField(
                controller: _newController,
                label: 'New password',
                validator: (v) =>
                    v == null || v.length < 6 ? 'Minimum 6 characters' : null,
              ),
              const SizedBox(height: 14),
              AppPasswordField(
                controller: _confirmController,
                label: 'Confirm new password',
                validator: (v) {
                  if (v != _newController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock_reset),
                label: Text(_busy ? 'Updating…' : 'Update password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
