import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/animal.dart';
import '../state/app_state.dart';
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
  late Future<List<Animal>> _animalsFuture;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedCategory;
  double? _minPrice;
  double? _maxPrice;
  bool _onlyVerifiedAnimals = false;
  bool _onlyVerifiedSellers = false;

  static const List<_AnimalCategory> _categoryOptions = [
    _AnimalCategory(
      labelKey: 'Cattle',
      value: 'CATTLE',
    ),
    _AnimalCategory(labelKey: 'Goat', value: 'GOAT'),
    _AnimalCategory(labelKey: 'Sheep', value: 'SHEEP'),
    _AnimalCategory(labelKey: 'Camel', value: 'CAMEL'),
    _AnimalCategory(labelKey: 'Chicken', value: 'CHICKEN'),
  ];

  @override
  void initState() {
    super.initState();
    _animalsFuture = _fetchAnimals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Animal>> _fetchAnimals() async {
    final api = context.read<AppState>().api;
    return api.getAnimals();
  }

  Future<void> _refresh() async {
    setState(() {
      _animalsFuture = _fetchAnimals();
    });
    await _animalsFuture;
  }

  Future<void> refreshFromShell() => _refresh();

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
    const actions = [
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
      _QuickMenuAction(
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
        final sheetWidth =
            (width * .65).clamp(280.0, width.toDouble()) as double;
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
                      Text(
                        context.tr('Powered by Legebere'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          letterSpacing: .4,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Legebere'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('Find quality livestock'),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .05),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: IconButton(
                        tooltip: context.tr('Open menu'),
                        onPressed: _showQuickMenu,
                        icon: const Icon(Icons.menu_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .05),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
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
                            icon: const Icon(
                              Icons.search_rounded,
                              color: Colors.grey,
                            ),
                            hintText: context.tr('Search livestock...'),
                            border: InputBorder.none,
                            isDense: true,
                            suffixIcon: _searchQuery.isEmpty
                                ? null
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
                    ],
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
                          setState(() {
                            _selectedCategory = selected
                                ? category.value
                                : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              FutureBuilder<List<Animal>>(
                future: _animalsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
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
                              onPressed: _refresh,
                              child: Text(context.tr('Retry')),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final items = snapshot.data ?? const <Animal>[];
                  if (items.isEmpty) {
                    return SliverToBoxAdapter(
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
                    );
                  }
                  final filteredItems = _filterAnimals(items);
                  if (filteredItems.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: EmptyState(
                          icon: Icons.filter_alt_rounded,
                          title: context.tr('No animals match your filters'),
                          description: context.tr(
                            'Try adjusting your filters or search.',
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: .62,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = filteredItems[index];
                      return LivestockCard(item: item);
                    }, childCount: filteredItems.length),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
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

    setState(() {
      _minPrice = result.minPrice;
      _maxPrice = result.maxPrice;
      _onlyVerifiedAnimals = result.onlyVerifiedAnimals;
      _onlyVerifiedSellers = result.onlyVerifiedSellers;
    });
  }

  Future<void> _openLanguagePicker() async {
    final appState = context.read<AppState>();
    final currentCode = appState.locale?.languageCode ?? 'en';

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
  const _AnimalCategory({
    required this.labelKey,
    required this.value,
  });

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
