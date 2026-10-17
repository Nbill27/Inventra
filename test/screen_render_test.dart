import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/core/app_theme.dart';
import 'package:peminjaman_barang/core/formatters.dart';
import 'package:peminjaman_barang/providers/loan_provider.dart';
import 'package:peminjaman_barang/repositories/item_repository.dart';
import 'package:peminjaman_barang/repositories/loan_repository.dart';
import 'package:peminjaman_barang/screens/home_screen.dart';
import 'package:peminjaman_barang/screens/loan_list_screen.dart';
import 'package:provider/provider.dart';

import 'support/test_database.dart';

void main() {
  testWidgets('LoanListScreen dan HomeScreen terbangun tanpa error', (
    tester,
  ) async {
    await initFormatters();

    final helper = createTestDatabase();
    final items = ItemRepository(helper: helper);
    final loans = LoanRepository(helper: helper);
    final provider = LoanProvider(repository: loans);

    // Basis data FFI menunggu event loop asli, sedangkan widget test memakai
    // jam palsu. Semua akses basis data diselesaikan lewat runAsync supaya
    // pengujian tidak menggantung sampai batas waktu.
    await tester.runAsync(() async {
      final itemId = await items.create(
        itemFixture(name: 'Proyektor Epson', code: 'PRJ-01'),
      );
      final tepat = await loans.create(
        loanFixture(itemId: itemId, borrowerName: 'Budi', quantity: 1),
      );
      final terlambat = await loans.create(
        loanFixture(itemId: itemId, borrowerName: 'Ani', quantity: 1),
      );
      await loans.markReturned(
        loanId: tepat,
        returnDate: DateTime(2026, 10, 6),
      );
      await loans.markReturned(
        loanId: terlambat,
        returnDate: DateTime(2026, 10, 9),
      );
      await loans.create(
        loanFixture(itemId: itemId, borrowerName: 'Cici', quantity: 1),
      );
      await provider.load();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: provider)],
        child: MaterialApp(theme: AppTheme.light, home: const LoanListScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Riwayat'), findsOneWidget);

    // HomeScreen ikut dipump supaya pola serupa ikut teruji.
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: provider)],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Daftar Peminjaman'), findsOneWidget);

    await tester.runAsync(helper.close);
  });
}
