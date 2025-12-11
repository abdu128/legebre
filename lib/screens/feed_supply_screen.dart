import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/feed_item.dart';
import '../state/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/feed_card.dart';
import 'add_feed_screen.dart';
import 'feed_detail_screen.dart';

class FeedSupplyScreen extends StatefulWidget {
  const FeedSupplyScreen({super.key});

  @override
  State<FeedSupplyScreen> createState() => _FeedSupplyScreenState();
}

class _FeedSupplyScreenState extends State<FeedSupplyScreen> {
  late Future<List<FeedItem>> _feedsFuture;
  final _searchController = TextEditingController();
  String _searchTerm = '';
  String _statusFilter = 'ALL';

  static const _statusOptions = [
    _StatusFilterOption('ALL', 'All feeds'),
    _StatusFilterOption('AVAILABLE', 'Available'),
    _StatusFilterOption('LOW_STOCK', 'Low stock'),
    _StatusFilterOption('OUT_OF_STOCK', 'Out of stock'),
  ];

  @override
  void initState() {
    super.initState();
    _feedsFuture = _loadFeeds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<FeedItem>> _loadFeeds() async {
    final api = context.read<AppState>().api;
    final filters = <String, dynamic>{};
    if (_searchTerm.isNotEmpty) filters['q'] = _searchTerm;
    if (_statusFilter != 'ALL') filters['status'] = _statusFilter;
    return api.getFeeds(filters: filters);
  }

  Future<void> _refresh() async {
    setState(() {
      _feedsFuture = _loadFeeds();
    });
    await _feedsFuture;
  }

  void _applySearch(String value) {
    setState(() {
      _searchTerm = value.trim();
      _feedsFuture = _loadFeeds();
    });
  }

  Future<void> _openAddListing() async {
    final shouldRefresh = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddFeedScreen()));
    if (shouldRefresh == true && mounted) {
      _refresh();
    }
  }

  void _openDetail(FeedItem feed) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => FeedDetailScreen(item: feed)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddListing,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add feed listing'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Feed supply',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bulk nutrition and supplements from trusted mills',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _HighlightCard(theme: theme),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _searchController,
                        onSubmitted: _applySearch,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: 'Search feed, brand, animal type...',
                          suffixIcon: _searchTerm.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _applySearch('');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : IconButton(
                                  onPressed: () =>
                                      _applySearch(_searchController.text),
                                  icon: const Icon(Icons.tune_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _statusOptions.map((option) {
                            final isSelected = _statusFilter == option.value;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(option.label),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _statusFilter = option.value;
                                    _feedsFuture = _loadFeeds();
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              FutureBuilder<List<FeedItem>>(
                future: _feedsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Could not load feed items',
                              style: theme.textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _refresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final items = snapshot.data ?? const <FeedItem>[];
                  if (items.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: EmptyState(
                          icon: Icons.storefront,
                          title: 'No feed listings yet',
                          description:
                              'Suppliers will publish feeds and supplements here soon.',
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 320,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: .72,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = items[index];
                        return FeedCard(
                          item: item,
                          onTap: () => _openDetail(item),
                        );
                      }, childCount: items.length),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGreen, AppColors.accentBlue],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: .25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk order support',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Need more than 5 tons? Chat with our sourcing team to lock fair rates.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: .9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryGreen,
            ),
            child: const Text('Contact'),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterOption {
  const _StatusFilterOption(this.value, this.label);

  final String value;
  final String label;
}
