import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/item_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/settings_provider.dart';
import '../services/reminder_scheduler.dart';
import 'home_screen.dart';
import 'item_list_screen.dart';
import 'loan_list_screen.dart';

/// Tiga tujuan: Beranda, Barang, Riwayat. Semuanya tetap hidup di dalam
/// [IndexedStack], sehingga teks pencarian dan posisi gulir bertahan saat
/// berpindah tab.
///
/// Tab "Beranda" menampilkan ringkasan [HomeScreen], sedangkan daftar lengkap
/// peminjaman ada di tab "Riwayat" ([LoanListScreen]).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const _beranda = 0;
  static const _barang = 1;
  static const _riwayat = 2;

  late int _index = widget.initialTab;
  ReminderScheduler? _reminders;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reminders = context.read<ReminderScheduler>()
      ..taps.addListener(_bukaDariNotifikasi);
    // Backup otomatis dicek sekali saat app dibuka: hanya berjalan bila
    // saklarnya nyala dan backup terakhir sudah lebih tua dari sebulan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SettingsProvider>().maybeRunMonthlyBackup();
        // Jadwal pengingat diperpanjang setiap app dibuka, sehingga horizon
        // 90 hari tidak pernah benar-benar habis dalam pemakaian normal.
        _reminders?.sync();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reminders?.sync();
    }
  }

  @override
  void dispose() {
    _reminders?.taps.removeListener(_bukaDariNotifikasi);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ketukan pada notifikasi pengingat selalu berakhir di daftar peminjaman.
  void _bukaDariNotifikasi() {
    if (!mounted) {
      return;
    }
    _kembaliKeBeranda();
  }

  /// Memuat ulang tab yang dibuka. Tanpa ini, ringkasan di beranda masih
  /// menampilkan angka lama setelah peminjaman dicatat di tab sebelah.
  Future<void> _onSelect(int index) async {
    if (index == _index) {
      return;
    }
    setState(() => _index = index);
    await switch (index) {
      _beranda => context.read<LoanProvider>().load(),
      _barang => context.read<ItemProvider>().load(),
      _riwayat => context.read<LoanProvider>().load(),
      _ => Future<void>.value(),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Android menyalurkan tombol back ke framework lewat
    // `OnBackPressedDispatcher`, dan `PopScope` yang menjadi kaitannya. Jadi
    // perilakunya diatur di sini, bukan di MainActivity.
    //
    // Back hanya menutup aplikasi dari tab Beranda. Dari tab lain, back lebih
    // dulu kembali ke tab Beranda supaya aplikasi tidak langsung tertutup.
    return PopScope(
      canPop: _index == _beranda,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _kembaliKeBeranda();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            const HomeScreen(),
            const ItemListScreen(),
            const LoanListScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onSelect,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Barang',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Riwayat',
            ),
          ],
        ),
      ),
    );
  }

  /// Dipakai tombol back: pindah ke tab Beranda tanpa menutup aplikasi.
  void _kembaliKeBeranda() {
    setState(() => _index = _beranda);
    // Sama seperti berpindah tab lewat navigasi bawah: datanya dimuat ulang,
    // karena isinya bisa berubah sejak tab ini terakhir dilihat.
    context.read<LoanProvider>().load();
  }
}
