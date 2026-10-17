import 'package:flutter/material.dart';

import '../core/app_breakpoint.dart';

/// Membatasi lebar konten lalu memusatkannya.
///
/// Di ponsel tidak berpengaruh sama sekali — lebar layar sudah di bawah
/// [AppBreakpoint.contentWidth], jadi anaknya mengisi penuh. Di tablet dan
/// perangkat terlipat, konten berhenti melebar sehingga panjang baris teks
/// tetap nyaman dibaca.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoint.contentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // Align (bukan Center) supaya anak yang butuh tinggi penuh — mis. ListView
    // — tetap mendapat batas tinggi dari induknya.
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
