import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/animal.dart';
import '../state/app_state.dart';
import '../widgets/category_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/livestock_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onMenuSelected});

  final ValueChanged<String> onMenuSelected;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Animal>> _animalsFuture;

  @override
  void initState() {
    super.initState();
    _animalsFuture = _fetchAnimals();
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

  Future<void> _showQuickMenu() async {
    final theme = Theme.of(context);
    final user = context.read<AppState>().user;
    const actions = [
      _QuickMenuAction(
        value: 'vet',
        icon: Icons.healing_rounded,
        label: 'Vet Care',
      ),
      _QuickMenuAction(value: 'feed', icon: Icons.grass, label: 'Feed Supply'),
      _QuickMenuAction(
        value: 'learn',
        icon: Icons.school_rounded,
        label: 'E-Learning',
      ),
      _QuickMenuAction(
        value: 'finance',
        icon: Icons.account_balance_wallet_rounded,
        label: 'Finance Info',
      ),
      _QuickMenuAction(
        value: 'logout',
        icon: Icons.logout_rounded,
        label: 'Logout',
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
      barrierLabel: 'Quick menu',
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
                                        text: user?.name ?? 'Guest user',
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
                                  displayPhone ?? 'Complete your profile',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
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
                                widget.onMenuSelected(action.value);
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
                                action.label,
                                style: theme.textTheme.titleMedium,
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Powered by Legebere',
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
                          'Legebere',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Find quality livestock',
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
                        tooltip: 'Open menu',
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
                    horizontal: 16,
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
                      const Icon(Icons.search_rounded, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search livestock...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.primaryGreen,
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
                    children: const [
                      CategoryChip(label: 'Cattle', icon: Icons.pets),
                      CategoryChip(label: 'Sheep', icon: Icons.cloud),
                      CategoryChip(label: 'Goat', icon: Icons.grass),
                      CategoryChip(label: 'Camel', icon: Icons.all_inclusive),
                    ],
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
                              'Failed to load listings',
                              style: theme.textTheme.titleMedium,
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
                  final items = snapshot.data ?? const <Animal>[];
                  if (items.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: EmptyState(
                          icon: Icons.pets,
                          title: 'No listings yet',
                          description:
                              'Animals added by the community will appear here.',
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
                      final item = items[index];
                      return LivestockCard(item: item);
                    }, childCount: items.length),
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
}

class _QuickMenuAction {
  const _QuickMenuAction({
    required this.value,
    required this.icon,
    required this.label,
  });

  final String value;
  final IconData icon;
  final String label;
}
