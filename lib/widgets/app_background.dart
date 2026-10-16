import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Latar global aplikasi — permukaan terang solid.
///
/// Dipasang sekali lewat `MaterialApp.builder` sehingga seluruh route, dialog,
/// dan sheet duduk di atasnya.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppTheme.surfaceBright),
      child: child,
    );
  }
}

/// Scrim solid untuk `AppBar.flexibleSpace` pada layar yang men-scroll, supaya
/// konten tidak bertabrakan dengan judul AppBar.
Widget appBarScrim() {
  return const DecoratedBox(
    decoration: BoxDecoration(color: AppTheme.surfaceBright),
  );
}
