import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Kartu solid putih dengan border tipis, tanpa bayangan.
///
/// Seluruh layar memakai satu bahasa kartu yang sama: putih + border halus.
/// Bayangan hanya dipakai elemen yang memang mengambang (FAB, sheet, dialog).
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spaceMd),
    this.radius = AppTheme.radiusPanel,
    this.fill,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? fill;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill ?? AppTheme.cardSolid,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? AppTheme.outlineVariant),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
