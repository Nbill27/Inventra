import 'package:flutter/material.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import 'panel.dart';

/// Tampilan saat daftar kosong atau pencarian tidak menemukan hasil.
///
/// Seluruh konten duduk di dalam [Panel] supaya layar kosong tetap punya satu
/// titik fokus, bukan sekadar area kosong di bawah app bar.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const <Widget>[],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

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
                    color: AppTheme.surfaceContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.outlineVariant),
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Text(
                  title,
                  style: AppText.headlineSm.copyWith(color: AppTheme.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppText.bodyMd.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spaceLg),
                  for (final action in actions) ...[
                    action,
                    const SizedBox(height: AppTheme.spaceSm),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
