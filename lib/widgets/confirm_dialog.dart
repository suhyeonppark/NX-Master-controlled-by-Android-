import 'package:flutter/material.dart';

/// Shows a large, high-contrast confirmation dialog for risky actions
/// (spec §11.3). Returns true if the operator pressed the confirm button.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String message,
  String title = '확인',
  String confirmLabel = '실행',
  String cancelLabel = '취소',
  bool danger = false,
}) async {
  final accent = danger ? Colors.red.shade700 : Theme.of(context).colorScheme.primary;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          danger ? Icons.warning_amber_rounded : Icons.help_outline,
          color: accent,
          size: 40,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            height: 56,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel, style: const TextStyle(fontSize: 18)),
            ),
          ),
          SizedBox(
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
