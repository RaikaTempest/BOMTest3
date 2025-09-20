import 'package:flutter/material.dart';

Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final theme = Theme.of(context);
  final confirmStyle = isDestructive
      ? FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
        )
      : null;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: confirmStyle,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return result ?? false;
}

Future<bool> showTextConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String hintText,
  required String expectedText,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final controller = TextEditingController();
  try {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                final matches =
                    controller.text.trim() == expectedText.trim();
                final theme = Theme.of(context);
                final confirmStyle = isDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      )
                    : null;
                return AlertDialog(
                  title: Text(title),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: InputDecoration(hintText: hintText),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(cancelLabel),
                    ),
                    FilledButton(
                      onPressed:
                          matches ? () => Navigator.of(context).pop(true) : null,
                      style: confirmStyle,
                      child: Text(confirmLabel),
                    ),
                  ],
                );
              },
            );
          },
        )) ??
        false;
  } finally {
    controller.dispose();
  }
}

