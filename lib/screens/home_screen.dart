import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/animal.dart';
import '../state/app_state.dart';
import '../utils/responsive.dart';
import '../widgets/category_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/livestock_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onMenuSelected});

  final ValueChanged<String> onMenuSelected;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Animal> _animals = [];
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _loadError;
  int _nextPage = 1;
  int _queryVersion = 0;

  static const int _pageSize = 20;

  String _searchQuery = '';
  String? _selectedCategory;
  double? _minPrice;
  double? _maxPrice;
  bool _onlyVerifiedAnimals = false;
  bool _onlyVerifiedSellers = false;

  static const List<_AnimalCategory> _categoryOptions = [
    _AnimalCategory(labelKey: 'Cattle', value: 'CATTLE'),
    _AnimalCategory(labelKey: 'Goat', value: 'GOAT'),
    _AnimalCategory(labelKey: 'Sheep', value: 'SHEEP'),
    _AnimalCategory(labelKey: 'Camel', value: 'CAMEL'),
    _AnimalCategory(labelKey: 'Chicken', value: 'CHICKEN'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadNextPage(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildApiFilters() {
    final filters = <String, dynamic>{};
    if (_selectedCategory != null) {
      filters['animalType'] = _selectedCategory;
    }
    if (_minPrice != null) {
      filters['minPrice'] = _minPrice;
    }
    if (_maxPrice != null) {
      filters['maxPrice'] = _maxPrice;
    }
    return filters;
  }

  Future<void> _loadNextPage({bool reset = false}) async {
    if (reset) {
      _queryVersion += 1;
      setState(() {
        _animals.clear();
        _nextPage = 1;
        _hasMore = true;
        _loadError = null;
        _isInitialLoading = true;
        _isLoadingMore = false;
      });
    } else {
      if (_isInitialLoading || _isLoadingMore || !_hasMore) {
        return;
      }
      setState(() {
        _isLoadingMore = true;
        _loadError = null;
      });
    }

    final currentQueryVersion = _queryVersion;
    final pageToLoad = _nextPage;

    try {
      final api = context.read<AppState>().api;
      final fetched = await api.getAnimals(
        filters: _buildApiFilters(),
        limit: _pageSize,
        page: pageToLoad,
      );

      if (!mounted || currentQueryVersion != _queryVersion) {
        return;
      }

      setState(() {
        _animals.addAll(fetched);
        _nextPage = pageToLoad + 1;
        _hasMore = fetched.length == _pageSize;
        _isInitialLoading = false;
        _isLoadingMore = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted || currentQueryVersion != _queryVersion) {
        return;
      }

      setState(() {
        _isInitialLoading = false;
        _isLoadingMore = false;
        _loadError = 'failed';
      });
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      _loadNextPage();
    }
  }

  Future<void> _refresh() async {
    await _loadNextPage(reset: true);
  }

  Future<void> refreshFromShell() => _refresh();

  Future<void> scrollToTopFromShell() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  bool get _filtersActive =>
      _selectedCategory != null ||
      _minPrice != null ||
      _maxPrice != null ||
      _onlyVerifiedAnimals ||
      _onlyVerifiedSellers;

  List<Animal> _filterAnimals(List<Animal> animals) {
    return animals.where((animal) {
      if (_selectedCategory != null &&
          animal.animalType.toUpperCase() != _selectedCategory) {
        return false;
      }
      if (_minPrice != null && animal.price < _minPrice!) return false;
      if (_maxPrice != null && animal.price > _maxPrice!) return false;
      if (_onlyVerifiedAnimals && !animal.verified) return false;
      if (_onlyVerifiedSellers && !animal.sellerVerified) return false;
      if (_searchQuery.isNotEmpty && !_matchesSearch(animal)) return false;
      return true;
    }).toList();
  }

  bool _matchesSearch(Animal animal) {
    if (_searchQuery.isEmpty) return true;
    final textQuery = _searchQuery.toLowerCase();
    final fields = <String?>[
      animal.animalType,
      animal.breed,
      animal.location,
      animal.description,
      animal.sellerName,
      animal.sellerPhone,
      animal.sellerWhatsapp,
      animal.age,
      animal.status,
    ];
    for (final field in fields) {
      if (field == null) continue;
      if (field.toLowerCase().contains(textQuery)) return true;
    }

    final numericQuery = RegExp(r'[0-9]').hasMatch(_searchQuery)
        ? _searchQuery.replaceAll(RegExp(r'[^0-9]'), '')
        : null;
    if (numericQuery != null && numericQuery.isNotEmpty) {
      final priceValue = animal.price.round().toString();
      if (priceValue.contains(numericQuery)) return true;
    }
    return false;
  }

  void _clearSearch() {
    if (_searchQuery.isEmpty) return;
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Future<void> _showQuickMenu() async {
    final theme = Theme.of(context);
    final user = context.read<AppState>().user;
    final actions = [
      // _QuickMenuAction(
      //   value: 'vet',
      //   icon: Icons.healing_rounded,
      //   labelKey: 'Vet Care',
      // ),
      _QuickMenuAction(
        value: 'feed',
        icon: Icons.grass,
        labelKey: 'Feed Supply',
      ),
      // _QuickMenuAction(
      //   value: 'learn',
      //   icon: Icons.school_rounded,
      //   labelKey: 'E-Learning',
      // ),
      _QuickMenuAction(
        value: 'finance',
        icon: Icons.account_balance_wallet_rounded,
        labelKey: 'Finance Info',
      ),
      _QuickMenuAction(
        value: 'language',
        icon: Icons.language_rounded,
        labelKey: 'Change language',
      ),
      if (user == null)
        const _QuickMenuAction(
          value: 'login',
          icon: Icons.login_rounded,
          labelKey: 'Login',
        )
      else
        const _QuickMenuAction(
          value: 'logout',
          icon: Icons.logout_rounded,
          labelKey: 'Logout',
        ),
    ];

    String? displayPhone;
    if (user != null && user.displayPhone.isNotEmpty) {
      displayPhone = user.displayPhone;
    } else if (user?.email != null && user!.email!.isNotEmpty) {
      displayPhone = user.email;
    }

    final fallbackInitial = (user != null && user.name.isNotEmpty)
        ? user.name.substring(0, 1).toUpperCase()
        : 'L';

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.tr('Quick menu'),
      barrierColor: Colors.black.withOpacity(.45),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final width = MediaQuery.of(context).size.width;
        final sheetWidth = (width * .65).clamp(280.0, width.toDouble());
        final slideAnimation =
            Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

        final sheet = Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(width: sheetWidth),
            child: Material(
              color: Colors.white,
              elevation: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                bottomLeft: Radius.circular(28),
              ),
              child: SafeArea(
                left: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: AppColors.primaryGreen.withValues(
                              alpha: .12,
                            ),
                            backgroundImage:
                                user?.profilePhoto != null &&
                                    user!.profilePhoto!.isNotEmpty
                                ? NetworkImage(user.profilePhoto!)
                                : null,
                            child:
                                user == null ||
                                    user.profilePhoto == null ||
                                    user.profilePhoto!.isEmpty
                                ? Text(
                                    fallbackInitial,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    children: [
                                      TextSpan(
                                        text:
                                            user?.name ??
                                            context.tr('Guest user'),
                                      ),
                                      if (user?.verified ?? false)
                                        const WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.middle,
                                          child: Padding(
                                            padding: EdgeInsets.only(left: 6),
                                            child: Icon(
                                              Icons.verified_rounded,
                                              size: 18,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayPhone ??
                                      context.tr('Complete your profile'),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: context.tr('Close'),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: actions.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.grey.withValues(alpha: .2),
                          ),
                          itemBuilder: (_, index) {
                            final action = actions[index];
                            return ListTile(
                              onTap: () {
                                Navigator.of(dialogContext).pop();
                                if (action.value == 'language') {
                                  _openLanguagePicker();
                                } else {
                                  widget.onMenuSelected(action.value);
                                }
                              },
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withValues(
                                    alpha: .08,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  action.icon,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              title: Text(
                                context.tr(action.labelKey),
                                style: theme.textTheme.titleMedium,
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Image.asset(
                        'assets/images/logo.png',
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Legebere',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepBrown,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        return SlideTransition(position: slideAnimation, child: sheet);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth + 180),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: kIsWeb ? 28 : 20,
              vertical: kIsWeb ? 20 : 16,
            ),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  if (kIsWeb)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryGreen.withValues(alpha: .92),
                              AppColors.secondaryGreen.withValues(alpha: .88),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compactBanner = constraints.maxWidth < 760;

                            if (compactBanner) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('Find quality livestock'),
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    context.tr(
                                      'Browse verified listings, compare prices, and connect with trusted sellers.',
                                    ),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: .92,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('Find quality livestock'),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  context.tr(
                                    'Browse verified listings, compare prices, and connect with trusted sellers.',
                                  ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: .92),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  if (!kIsWeb)
                    SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Image.asset(
                                  'assets/images/logo.png',
                                  height: 36,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Legebere',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.deepBrown,
                                    letterSpacing: -.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.tr('Find quality livestock'),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            elevation: 2,
                            shadowColor: Colors.black.withValues(alpha: .08),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _openFiltersSheet,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Icon(
                                  _filtersActive
                                      ? Icons.filter_alt_rounded
                                      : Icons.filter_alt_outlined,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            elevation: 2,
                            shadowColor: Colors.black.withValues(alpha: .08),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _showQuickMenu,
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(
                                  Icons.menu_rounded,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: .06),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: TextField(
                          controller: _searchController,
                          cursorColor: AppColors.primaryGreen,
                          textInputAction: TextInputAction.search,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.trim();
                            });
                          },
                          decoration: InputDecoration(
                            icon: Icon(
                              Icons.search_rounded,
                              color: Colors.grey.shade400,
                            ),
                            hintText: context.tr('Search livestock...'),
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            suffixIcon: _searchQuery.isEmpty
                                ? IconButton(
                                    onPressed: _openFiltersSheet,
                                    tooltip: context.tr('Filters'),
                                    icon: Icon(
                                      _filtersActive
                                          ? Icons.filter_alt_rounded
                                          : Icons.filter_alt_outlined,
                                      color: AppColors.primaryGreen,
                                    ),
                                  )
                                : IconButton(
                                    onPressed: _clearSearch,
                                    tooltip: context.tr('Close'),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _categoryOptions.map((category) {
                          final label = context.tr(category.labelKey);
                          return CategoryChip(
                            label: label,
                            selected: _selectedCategory == category.value,
                            onSelected: (selected) {
                              final nextCategory = selected
                                  ? category.value
                                  : null;
                              if (nextCategory == _selectedCategory) {
                                return;
                              }
                              setState(() {
                                _selectedCategory = nextCategory;
                              });
                              _loadNextPage(reset: true);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  if (_isInitialLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (_loadError != null && _animals.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.cloud_off,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('Failed to load listings'),
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => _loadNextPage(reset: true),
                              child: Text(context.tr('Retry')),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_animals.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: EmptyState(
                          icon: Icons.pets,
                          title: context.tr('No listings yet'),
                          description: context.tr(
                            'Animals added by the community will appear here.',
                          ),
                        ),
                      ),
                    )
                  else ...[
                    Builder(
                      builder: (context) {
                        final filteredItems = _filterAnimals(_animals);
                        if (filteredItems.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: EmptyState(
                                icon: Icons.filter_alt_rounded,
                                title: context.tr(
                                  'No animals match your filters',
                                ),
                                description: context.tr(
                                  'Try adjusting your filters or search.',
                                ),
                              ),
                            ),
                          );
                        }
                        return SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.crossAxisExtent;
                            final maxExtent = width >= 1280
                                ? 320.0
                                : width >= 980
                                ? 290.0
                                : 240.0;
                            return SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: maxExtent,
                                    crossAxisSpacing: kIsWeb ? 18 : 14,
                                    mainAxisSpacing: kIsWeb ? 18 : 14,
                                    childAspectRatio: .58,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final item = filteredItems[index];
                                return LivestockCard(item: item);
                              }, childCount: filteredItems.length),
                            );
                          },
                        );
                      },
                    ),
                    if (_isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (_loadError != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: TextButton(
                              onPressed: _loadNextPage,
                              child: Text(context.tr('Retry')),
                            ),
                          ),
                        ),
                      ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFiltersSheet() async {
    FocusScope.of(context).unfocus();
    final minController = TextEditingController(
      text: _minPrice?.round().toString() ?? '',
    );
    final maxController = TextEditingController(
      text: _maxPrice?.round().toString() ?? '',
    );

    double? parsePrice(String value) {
      final sanitized = value.replaceAll(RegExp(r'[^0-9.]'), '').trim();
      if (sanitized.isEmpty) return null;
      return double.tryParse(sanitized);
    }

    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        bool verifiedAnimals = _onlyVerifiedAnimals;
        bool verifiedSellers = _onlyVerifiedSellers;
        final theme = Theme.of(sheetContext);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Filters'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('Price range'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: context.tr('Minimum price'),
                              prefixText: 'Br ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: context.tr('Maximum price'),
                              prefixText: 'Br ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      value: verifiedAnimals,
                      onChanged: (value) =>
                          setModalState(() => verifiedAnimals = value),
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Verified livestock only')),
                    ),
                    SwitchListTile.adaptive(
                      value: verifiedSellers,
                      onChanged: (value) =>
                          setModalState(() => verifiedSellers = value),
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Verified sellers only')),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              minController.clear();
                              maxController.clear();
                              verifiedAnimals = false;
                              verifiedSellers = false;
                            });
                          },
                          child: Text(context.tr('Reset filters')),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: Text(context.tr('Cancel')),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(
                              _FilterResult(
                                minPrice: parsePrice(minController.text),
                                maxPrice: parsePrice(maxController.text),
                                onlyVerifiedAnimals: verifiedAnimals,
                                onlyVerifiedSellers: verifiedSellers,
                              ),
                            );
                          },
                          child: Text(context.tr('Apply filters')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    minController.dispose();
    maxController.dispose();

    if (result == null) return;

    final hasChanged =
        _minPrice != result.minPrice ||
        _maxPrice != result.maxPrice ||
        _onlyVerifiedAnimals != result.onlyVerifiedAnimals ||
        _onlyVerifiedSellers != result.onlyVerifiedSellers;

    setState(() {
      _minPrice = result.minPrice;
      _maxPrice = result.maxPrice;
      _onlyVerifiedAnimals = result.onlyVerifiedAnimals;
      _onlyVerifiedSellers = result.onlyVerifiedSellers;
    });

    if (hasChanged) {
      _loadNextPage(reset: true);
    }
  }

  Future<void> _openLanguagePicker() async {
    final appState = context.read<AppState>();
    final currentCode = appState.locale.languageCode;

    final selectedCode = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Select language'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...AppLocalizations.supportedLocales.map((locale) {
                  final label = switch (locale.languageCode) {
                    'am' => context.tr('Amharic'),
                    'om' => context.tr('Afan Oromo'),
                    'so' => context.tr('Somali'),
                    _ => context.tr('English'),
                  };
                  return RadioListTile<String>(
                    value: locale.languageCode,
                    groupValue: currentCode,
                    onChanged: (value) => Navigator.of(sheetContext).pop(value),
                    title: Text(label),
                  );
                }),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(context.tr('Close')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedCode != null && selectedCode != currentCode) {
      await appState.setLocale(Locale(selectedCode));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('Language updated'))));
      }
    }
  }
}

class _FilterResult {
  const _FilterResult({
    this.minPrice,
    this.maxPrice,
    required this.onlyVerifiedAnimals,
    required this.onlyVerifiedSellers,
  });

  final double? minPrice;
  final double? maxPrice;
  final bool onlyVerifiedAnimals;
  final bool onlyVerifiedSellers;
}

class _AnimalCategory {
  const _AnimalCategory({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}

class _QuickMenuAction {
  const _QuickMenuAction({
    required this.value,
    required this.icon,
    required this.labelKey,
  });

  final String value;
  final IconData icon;
  final String labelKey;
}
