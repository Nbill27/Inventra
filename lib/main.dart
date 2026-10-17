import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/formatters.dart';
import 'providers/item_provider.dart';
import 'providers/loan_provider.dart';
import 'screens/home_shell.dart';
import 'widgets/app_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Status bar transparan dengan ikon GELAP: latar aplikasi terang solid, jadi
  // ikon putih akan hilang di atas putih.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  // Nama bulan Indonesia harus dimuat sebelum tanggal pertama diformat,
  // kalau tidak `intl` melempar error di baris daftar pertama.
  await initFormatters();
  runApp(const PeminjamanBarangApp());
}

class PeminjamanBarangApp extends StatelessWidget {
  const PeminjamanBarangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ItemProvider()..load()),
        ChangeNotifierProvider(create: (_) => LoanProvider()..load()),
      ],
      child: MaterialApp(
        title: 'Inventra',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // Latar solid global di belakang seluruh Navigator, sehingga semua
        // route, dialog, dan sheet duduk di atas permukaan yang sama.
        builder: (context, child) =>
            AppBackground(child: child ?? const SizedBox.shrink()),
        home: const HomeShell(),
      ),
    );
  }
}
