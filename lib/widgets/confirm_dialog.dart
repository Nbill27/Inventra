import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Konfirmasi sebelum sesuatu yang merusak atau mengubah stok dijalankan.
/// Mengembalikan true hanya saat tombol konfirmasi ditekan, jadi dialog yang
/// ditutup berarti "jangan lakukan apa-apa".
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: AppTheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
