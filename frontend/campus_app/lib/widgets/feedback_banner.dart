import 'package:flutter/material.dart';

enum FeedbackType { success, error, info }

/// Inline banner for form-level success/error feedback.
class FeedbackBanner extends StatelessWidget {
  final String message;
  final FeedbackType type;
  final VoidCallback? onDismiss;

  const FeedbackBanner({
    super.key,
    required this.message,
    required this.type,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (type) {
      FeedbackType.success => (
          Colors.green.shade50,
          Colors.green.shade900,
          Icons.check_circle_outline,
        ),
      FeedbackType.error => (
          Colors.red.shade50,
          Colors.red.shade900,
          Icons.error_outline,
        ),
      FeedbackType.info => (
          Colors.blue.shade50,
          Colors.blue.shade900,
          Icons.info_outline,
        ),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: fg, fontWeight: FontWeight.w500),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: Icon(Icons.close, size: 18, color: fg),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}

void showAppSnackBar(
  BuildContext context, {
  required String message,
  required bool success,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: Duration(seconds: success ? 3 : 4),
      ),
    );
}

Future<void> showSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
  VoidCallback? onOk,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.check_circle, color: Colors.green.shade600, size: 48),
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            onOk?.call();
          },
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}
