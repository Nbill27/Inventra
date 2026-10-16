import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/item_provider.dart';
import '../providers/loan_provider.dart';
import 'item_list_screen.dart';
import 'loan_list_screen.dart';

/// Two destinations only (PRD §8). Both stay alive in an [IndexedStack], so
/// search text and scroll position survive a tab switch.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialTab;

  /// Reloads the tab being opened. Without this, a loan listed here still shows
  /// an item name that was edited on the other tab.
  Future<void> _onSelect(int index) async {
    if (index == _index) {
      return;
    }
    setState(() => _index = index);
    await (index == 0
        ? context.read<ItemProvider>().load()
        : context.read<LoanProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [ItemListScreen(), LoanListScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onSelect,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Barang',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Peminjaman',
          ),
        ],
      ),
    );
  }
}
