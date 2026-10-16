import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/formatters.dart';
import 'providers/item_provider.dart';
import 'providers/loan_provider.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Indonesian month names must be loaded before the first date is formatted,
  // otherwise `intl` throws on the first list row that shows a date.
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
        title: 'Peminjaman Barang',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Follows the phone setting on purpose; there is no in-app toggle.
        themeMode: ThemeMode.system,
        home: const HomeShell(),
      ),
    );
  }
}
