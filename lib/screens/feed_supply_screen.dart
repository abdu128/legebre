import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/feed_item.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/feed_card.dart';
import 'add_feed_screen.dart';
import 'feed_detail_screen.dart';
import '../utils/seller_guard.dart';

class FeedSupplyScreen extends StatefulWidget {
  const FeedSupplyScreen({super.key});

  @override
  State<FeedSupplyScreen> createState() => _FeedSupplyScreenState();
}

class _FeedSupplyScreenState extends State<FeedSupplyScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FeedItem> _feeds = [];
  final _searchController = TextEditingController();
  String _searchTerm = '';
  String _statusFilter = 'ALL';
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _loadError;
  int _nextPage = 1;
  int _queryVersion = 0;

  static const int _pageSize = 20;

  static const _statusOptions = [
    _StatusFilterOption('ALL', 'All feeds'),
    _StatusFilterOption('AVAILABLE', 'Available'),
    _StatusFilterOption('LOW_STOCK', 'Low stock'),
    _StatusFilterOption('OUT_OF_STOCK', 'Out of stock'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadFeeds(reset: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildFilters() {
    final filters = <String, dynamic>{};
    if (_searchTerm.isNotEmpty) filters['q'] = _searchTerm;
    if (_statusFilter != 'ALL') filters['status'] = _statusFilter;
    return filters;
  }

  Future<void> _loadFeeds({bool reset = false}) async {
    if (reset) {
      _queryVersion += 1;
      setState(() {
        _feeds.clear();
        _nextPage = 1;
        _hasMore = true;
        _loadError = null;
        _isInitialLoading = true;
        _isLoadingMore = false;
      });
    } else {
      if (_isInitialLoading || _isLoadingMore || !_hasMore) return;
      setState(() {
        _isLoadingMore = true;
        _loadError = null;
      });
    }

    final queryVersion = _queryVersion;
    final pageToLoad = _nextPage;

    final api = context.read<AppState>().api;
    try {
      final fetched = await api.getFeeds(
        filters: _buildFilters(),
        page: pageToLoad,
        limit: _pageSize,
      );
      if (!mounted || queryVersion != _queryVersion) return;

      setState(() {
        _feeds.addAll(fetched);
        _nextPage = pageToLoad + 1;
        _hasMore = fetched.length == _pageSize;
        _isInitialLoading = false;
        _isLoadingMore = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted || queryVersion != _queryVersion) return;
      setState(() {
        _isInitialLoading = false;
        _isLoadingMore = false;
        _loadError = 'failed';
      });
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      _loadFeeds();
    }
  }

  Future<void> _refresh() async {
    await _loadFeeds(reset: true);
  }

  void _applySearch(String value) {
    setState(() {
      _searchTerm = value.trim();
    });
    _loadFeeds(reset: true);
  }

  Future<void> _openAddListing() async {
    final allowed = await SellerGuard.ensureSeller(context);
    if (!allowed) return;
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
        label: Text(context.tr('Add feed listing')),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController,
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
                                context.tr('Feed Supply'),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
                          hintText: context.tr(
                            'Search feed, brand, animal type...',
                          ),
                          suffixIcon: _searchTerm.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _applySearch('');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : null,
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
                                label: Text(context.tr(option.label)),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _statusFilter = option.value;
                                  });
                                  _loadFeeds(reset: true);
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
              if (_isInitialLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_loadError != null && _feeds.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('Could not load feed items'),
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _loadFeeds(reset: true),
                          child: Text(context.tr('Retry')),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_feeds.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: EmptyState(
                      icon: Icons.storefront,
                      title: context.tr('No feed listings yet'),
                      description: context.tr(
                        'Suppliers will publish feeds and supplements here soon.',
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 320,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: .64,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = _feeds[index];
                      return FeedCard(
                        item: item,
                        onTap: () => _openDetail(item),
                      );
                    }, childCount: _feeds.length),
                  ),
                ),
              if (_isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_loadError != null && _feeds.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: TextButton(
                        onPressed: _loadFeeds,
                        child: Text(context.tr('Retry')),
                      ),
                    ),
                  ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        final textBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Bulk order support'),
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Chat with our sourcing team to lock fair rates.'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: .9),
              ),
            ),
          ],
        );

        final contactButton = FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primaryGreen,
            minimumSize: const Size(120, 44),
          ),
          child: Text(context.tr('Contact')),
        );

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
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textBlock,
                    const SizedBox(height: 16),
                    contactButton,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: textBlock),
                    const SizedBox(width: 12),
                    contactButton,
                  ],
                ),
        );
      },
    );
  }
}

class _StatusFilterOption {
  const _StatusFilterOption(this.value, this.label);

  final String value;
  final String label;
}
