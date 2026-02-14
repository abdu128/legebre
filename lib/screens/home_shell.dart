import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'add_listing_screen.dart';
import 'e_learning_screen.dart';
import 'favorites_screen.dart';
import 'feed_supply_screen.dart';
import 'home_screen.dart';
import 'financial_info_screen.dart';
import 'vet_care_screen.dart';
import '../utils/seller_guard.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  final _homeKey = GlobalKey<HomeScreenState>();
  late final HomeScreen _homeScreen;

  @override
  void initState() {
    super.initState();
    _homeScreen = HomeScreen(
      key: _homeKey,
      onMenuSelected: _handleMenuSelection,
    );
  }

  Future<void> _handleFabPressed() async {
    final allowed = await SellerGuard.ensureSeller(context);
    if (!allowed || !mounted) return;
    final shouldRefresh = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddListingScreen()));
    if (shouldRefresh == true && mounted) {
      final state = _homeKey.currentState;
      if (state != null) await state.refreshFromShell();
    }
  }

  void _handleMenuSelection(String value) {
    if (value == 'feed') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const FeedSupplyScreen()));
    } else if (value == 'vet') {
      setState(() => _currentIndex = 2);
    } else if (value == 'learn') {
      setState(() => _currentIndex = 3);
    } else if (value == 'finance') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const FinancialInfoScreen()));
    } else if (value == 'logout') {
      context.read<AppState>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _homeScreen,
      const FavoritesScreen(),
      const VetCareScreen(),
      const ELearningScreen(),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: pages[_currentIndex],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _handleFabPressed,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('Sell livestock')),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_rounded),
            label: context.tr('Home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_rounded),
            label: context.tr('Favorites'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.medical_services_rounded),
            label: context.tr('Vet'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book_rounded),
            label: context.tr('Learn'),
          ),
        ],
      ),
    );
  }
}
