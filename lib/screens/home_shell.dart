import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  bool _compactFooterExpanded = false;
  bool _showWebFooter = true;
  Timer? _footerShowDebounce;
  final _homeKey = GlobalKey<HomeScreenState>();
  late final HomeScreen _homeScreen;

  @override
  void dispose() {
    _footerShowDebounce?.cancel();
    super.dispose();
  }

  void _setWebFooterVisible(bool visible) {
    if (!mounted || _showWebFooter == visible) return;
    setState(() {
      _showWebFooter = visible;
    });
  }

  bool _handleWebScrollNotification(ScrollNotification notification) {
    if (!kIsWeb) return false;

    // React only to the main vertical page scroll, not nested/horizontal carousels.
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      _footerShowDebounce?.cancel();
      _setWebFooterVisible(false);
      return false;
    }

    if (notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle)) {
      _footerShowDebounce?.cancel();
      _footerShowDebounce = Timer(const Duration(milliseconds: 320), () {
        _setWebFooterVisible(true);
      });
    }

    return false;
  }

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

  Future<void> _scrollHomeToTop() async {
    if (_currentIndex != 0) {
      await _handleIndexTap(0);
    }

    if (!mounted) return;

    // Wait one frame if page changed so HomeScreen is ready to animate.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final state = _homeKey.currentState;
    if (state != null) {
      await state.scrollToTopFromShell();
    }
  }

  Widget _buildWebTopBar() {
    final appState = context.watch<AppState>();
    final viewportWidth = MediaQuery.of(context).size.width;
    final compactScreen = viewportWidth < 980;
    final labels = [
      context.tr('Home'),
      context.tr('Favorites'),
      context.tr('Vet'),
      context.tr('Learn'),
    ];

    final navButtons = List<Widget>.generate(labels.length, (index) {
      final selected = _currentIndex == index;
      return TextButton(
        onPressed: () => _handleIndexTap(index),
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.white : Colors.black87,
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(labels[index]),
      );
    });

    final authButton = appState.isAuthenticated
        ? OutlinedButton(
            onPressed: () => context.read<AppState>().logout(),
            child: Text(context.tr('Logout')),
          )
        : OutlinedButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
            child: const Text('Sign in / Register'),
          );

    final actionButtons = <Widget>[
      ...navButtons,
      if (_currentIndex == 0)
        FilledButton.icon(
          onPressed: _handleFabPressed,
          icon: const Icon(Icons.add_rounded),
          label: Text(context.tr('Sell livestock')),
        ),
      authButton,
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: compactScreen ? 16 : 28,
        vertical: compactScreen ? 10 : 14,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactLayout = constraints.maxWidth < 980;

          if (compactLayout) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: context.tr('Menu'),
                      onSelected: (value) async {
                        if (value.startsWith('nav-')) {
                          final index = int.tryParse(value.split('-').last);
                          if (index != null) {
                            await _handleIndexTap(index);
                          }
                          return;
                        }
                        if (value == 'sell') {
                          await _handleFabPressed();
                          return;
                        }
                        if (value == 'auth') {
                          if (appState.isAuthenticated) {
                            context.read<AppState>().logout();
                          } else {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AuthScreen(),
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) {
                        final items = <PopupMenuEntry<String>>[];
                        for (var i = 0; i < labels.length; i++) {
                          items.add(
                            PopupMenuItem<String>(
                              value: 'nav-$i',
                              child: Row(
                                children: [
                                  if (_currentIndex == i)
                                    const Icon(Icons.check_rounded, size: 16)
                                  else
                                    const SizedBox(width: 16),
                                  const SizedBox(width: 8),
                                  Text(labels[i]),
                                ],
                              ),
                            ),
                          );
                        }
                        if (_currentIndex == 0) {
                          items.add(const PopupMenuDivider());
                          items.add(
                            PopupMenuItem<String>(
                              value: 'sell',
                              child: Text(context.tr('Sell livestock')),
                            ),
                          );
                        }
                        items.add(const PopupMenuDivider());
                        items.add(
                          PopupMenuItem<String>(
                            value: 'auth',
                            child: Text(
                              appState.isAuthenticated
                                  ? context.tr('Logout')
                                  : 'Sign in / Register',
                            ),
                          ),
                        );
                        return items;
                      },
                      icon: const Icon(Icons.menu_rounded),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
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
              const SizedBox(width: 16),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    runAlignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: actionButtons,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWebFooter() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0E3E2A), const Color(0xFF156945)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;

          if (compact) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(5),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Legebere',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                        onPressed: _scrollHomeToTop,
                        child: const Text('Back to top'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Find quality livestock, compare prices, and transact confidently with trusted sellers.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: .9),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildFooterStat('5k+', 'Listings'),
                      _buildFooterStat('1k+', 'Active buyers'),
                      _buildFooterStat('99%', 'Verified sellers'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(color: Colors.white.withValues(alpha: .2), height: 1),
                  const SizedBox(height: 8),
                  Text(
                    'Copyright ${DateTime.now().year} Legebere',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: .82),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Built for modern livestock commerce',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: .82),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildFooterBrand(theme)),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: _buildFooterQuickLinks(theme)),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: _buildFooterHighlights(theme)),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(color: Colors.white.withValues(alpha: .2), height: 1),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      'Copyright ${DateTime.now().year} Legebere',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: .82),
                      ),
                    ),
                    Text(
                      'Built for modern livestock commerce',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: .82),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactFooterChip(String label, Future<void> Function() onTap) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: .35)),
        backgroundColor: Colors.white.withValues(alpha: .06),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () {
        onTap();
      },
      child: Text(label),
    );
  }

  Widget _buildFooterBrand(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(7),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            Text(
              'Legebere',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'Find quality livestock, compare prices, and transact confidently with trusted sellers.',
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: .9),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFooterStat('5k+', 'Listings'),
            _buildFooterStat('1k+', 'Active buyers'),
            _buildFooterStat('99%', 'Verified sellers'),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterQuickLinks(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick links',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _buildFooterLink('Browse listings', () => _handleIndexTap(0)),
        _buildFooterLink('Back to top', _scrollHomeToTop),
        _buildFooterLink('Favorites', () => _handleIndexTap(1)),
        _buildFooterLink('Vet care', () => _handleIndexTap(2)),
        _buildFooterLink('E-learning', () => _handleIndexTap(3)),
        _buildFooterLink('Sell livestock', _handleFabPressed),
      ],
    );
  }

  Widget _buildFooterHighlights(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stay connected',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Market updates, expert vet support, and finance resources in one place.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: .9),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            _buildSocialButton(Icons.public_rounded, 'Website'),
            _buildSocialButton(Icons.forum_rounded, 'Community'),
            _buildSocialButton(Icons.mail_outline_rounded, 'Contact'),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
          foregroundColor: Colors.white.withValues(alpha: .95),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
        ),
        onPressed: onTap,
        icon: const Icon(Icons.arrow_right_alt_rounded, size: 18),
        label: Text(label),
      ),
    );
  }

  Widget _buildFooterStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String label) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: .35)),
        backgroundColor: Colors.white.withValues(alpha: .07),
      ),
      onPressed: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label coming soon')));
      },
      icon: Icon(icon, size: 16),
      label: Text(label),
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

    if (kIsWeb) {
      final compactWeb = MediaQuery.of(context).size.width < 980;
      return Scaffold(
        body: Column(
          children: [
            _buildWebTopBar(),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleWebScrollNotification,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: KeyedSubtree(
                    key: ValueKey(_currentIndex),
                    child: pages[_currentIndex],
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: child,
                  ),
                );
              },
              child: _showWebFooter
                  ? KeyedSubtree(
                      key: const ValueKey('web-footer-visible'),
                      child: compactWeb && _currentIndex != 0
                          ? const SizedBox.shrink()
                          : _buildWebFooter(),
                    )
                  : const SizedBox(key: ValueKey('web-footer-hidden')),
            ),
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
