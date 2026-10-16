import 'package:flutter/material.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import 'panel.dart';

/// Setiap kegagalan memuat data berakhir di sini (NFR-7): penyebabnya tetap di
/// layar bersama satu tombol ulangi, bukan aplikasi yang terlihat kosong.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Panel(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceLg,
              vertical: AppTheme.spaceXl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.outlineVariant),
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 40,
                    color: AppTheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Text(
                  'Gagal memuat data',
                  style: AppText.headlineSm.copyWith(color: AppTheme.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  message,
                  style: AppText.bodyMd.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: AppTheme.spaceLg),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
