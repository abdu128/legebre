import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'add_listing_screen.dart';
import 'e_learning_screen.dart';
import 'favorites_screen.dart';
import 'feed_supply_screen.dart';
import 'home_screen.dart';
import 'vet_care_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  late final HomeScreen _homeScreen;

  @override
  void initState() {
    super.initState();
    _homeScreen = HomeScreen(onMenuSelected: _handleMenuSelection);
  }

  void _handleFabPressed() {
    setState(() {
      _currentIndex = 2;
    });
  }

  void _handleMenuSelection(String value) {
    if (value == 'feed') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const FeedSupplyScreen()));
    } else if (value == 'vet') {
      setState(() => _currentIndex = 3);
    } else if (value == 'learn') {
      setState(() => _currentIndex = 4);
    } else if (value == 'finance') {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finance information',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Get micro-loans and savings tips for livestock farming. '
                'Visit your nearby cooperative for more support.',
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
        ),
      );
    } else if (value == 'logout') {
      context.read<AppState>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _homeScreen,
      const FavoritesScreen(),
      // const AddListingScreen(),
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
              label: const Text('Sell livestock'),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_rounded),
            label: 'Favorites',
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.add_box_rounded),
          //   label: 'Add',
          // ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services_rounded),
            label: 'Vet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Learn',
          ),
        ],
      ),
    );
  }
}
