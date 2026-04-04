import 'package:flutter/foundation.dart';
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
import 'auth_screen.dart';

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

  Future<void> _handleIndexTap(int index) async {
    final appState = context.read<AppState>();
    if (!appState.isAuthenticated && index == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please log in to continue'))),
      );
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }
    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  Widget _buildWebTopBar() {
    final appState = context.watch<AppState>();
    final labels = [
      context.tr('Home'),
      context.tr('Favorites'),
      context.tr('Vet'),
      context.tr('Learn'),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      child: Row(
        children: [
          Row(
            children: [
              Image.asset('assets/images/logo.png', height: 34),
              const SizedBox(width: 10),
              Text(
                'Legebere',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Wrap(
            spacing: 8,
            children: List.generate(labels.length, (index) {
              final selected = _currentIndex == index;
              return TextButton(
                onPressed: () => _handleIndexTap(index),
                style: TextButton.styleFrom(
                  foregroundColor: selected ? Colors.white : Colors.black87,
                  backgroundColor: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(labels[index]),
              );
            }),
          ),
          const SizedBox(width: 12),
          if (_currentIndex == 0)
            FilledButton.icon(
              onPressed: _handleFabPressed,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('Sell livestock')),
            ),
          const SizedBox(width: 10),
          appState.isAuthenticated
              ? OutlinedButton(
                  onPressed: () => context.read<AppState>().logout(),
                  child: Text(context.tr('Logout')),
                )
              : OutlinedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
                  child: Text(context.tr('Login')),
                ),
        ],
      ),
    );
  }

  Widget _buildWebFooter() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8,
        children: [
          Text(
            'Legebere',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            context.tr('Find quality livestock'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            'Copyright ${DateTime.now().year} Legebere',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
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
    } else if (value == 'login') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
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

    final appState = context.watch<AppState>();

    if (kIsWeb) {
      return Scaffold(
        body: Column(
          children: [
            _buildWebTopBar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: KeyedSubtree(
                  key: ValueKey(_currentIndex),
                  child: pages[_currentIndex],
                ),
              ),
            ),
            _buildWebFooter(),
          ],
        ),
      );
    }

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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _handleIndexTap,
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
      ),
    );
  }
}
