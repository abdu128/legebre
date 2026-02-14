import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/animal.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/livestock_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Animal>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = _loadFavorites();
  }

  Future<List<Animal>> _loadFavorites() async {
    final api = context.read<AppState>().api;
    return api.getFavorites();
  }

  Future<void> _refresh() async {
    setState(() {
      _favoritesFuture = _loadFavorites();
    });
    await _favoritesFuture;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Favorites'),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<Animal>>(
                  future: _favoritesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ],
                      );
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          const Center(child: Icon(Icons.cloud_off, size: 48)),
                          const SizedBox(height: 12),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  context.tr('Unable to load favorites'),
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _refresh,
                                  child: Text(context.tr('Retry')),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    final items = snapshot.data ?? const <Animal>[];
                    if (items.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          EmptyState(
                            icon: Icons.favorite_border,
                            title: context.tr('No favorites yet'),
                            description: context.tr(
                              'Save animals you like to view them later.',
                            ),
                          ),
                        ],
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: items.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: .62,
                          ),
                      itemBuilder: (_, index) =>
                          LivestockCard(item: items[index]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
