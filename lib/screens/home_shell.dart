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

  Future<void> _showCompactWebMenu({
    required AppState appState,
    required List<String> labels,
    required BuildContext anchorContext,
  }) async {
    final navIcons = <IconData>[
      Icons.home_rounded,
      Icons.favorite_rounded,
      Icons.medical_services_rounded,
      Icons.menu_book_rounded,
    ];

    final theme = Theme.of(context);

    Future<void> handleSelection(String value) async {
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
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
        }
      }
    }

    final button = anchorContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) {
      return;
    }

    final buttonRect = Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
    );

    final selectedValue = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(buttonRect, Offset.zero & overlay.size),
      color: Colors.white,
      elevation: 12,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 290),
      items: [
        for (int index = 0; index < labels.length; index++)
          PopupMenuItem<String>(
            value: 'nav-$index',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Builder(
              builder: (context) {
                final selected = _currentIndex == index;
                return Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primary.withValues(alpha: .1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        navIcons[index],
                        size: 20,
                        color: selected
                            ? theme.colorScheme.primary
                            : Colors.black87,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          labels[index],
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? theme.colorScheme.primary
                                : Colors.black87,
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (_currentIndex == 0)
          PopupMenuItem<String>(
            value: 'sell',
            enabled: true,
            height: 56,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('Sell livestock'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'auth',
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: .16)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  appState.isAuthenticated
                      ? Icons.logout_rounded
                      : Icons.login_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  appState.isAuthenticated
                      ? context.tr('Logout')
                      : 'Sign in / Register',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (selectedValue != null) {
      await handleSelection(selectedValue);
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
                    Builder(
                      builder: (menuButtonContext) {
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          elevation: 1,
                          shadowColor: Colors.black.withValues(alpha: .08),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _showCompactWebMenu(
                              appState: appState,
                              labels: labels,
                              anchorContext: menuButtonContext,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(Icons.menu_rounded),
                            ),
                          ),
                        );
                      },
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
          final denseDesktop = constraints.maxWidth >= 1280;

          if (compact) {
            final textColor = Colors.white.withValues(alpha: .9);
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
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          setState(() {
                            _compactFooterExpanded = !_compactFooterExpanded;
                          });
                        },
                        icon: Icon(
                          _compactFooterExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _compactFooterExpanded ? 'Show less' : 'Show more',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(color: Colors.white.withValues(alpha: .2), height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Copyright ${DateTime.now().year} Legebere',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: .82),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(
                              'Find quality livestock, compare prices, and transact confidently with trusted sellers.',
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: textColor,
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildCompactFooterChip('Browse', () async {
                                await _handleIndexTap(0);
                              }),
                              _buildCompactFooterChip('Favorites', () async {
                                await _handleIndexTap(1);
                              }),
                              _buildCompactFooterChip('Sell', () async {
                                await _handleFabPressed();
                              }),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Built for modern livestock commerce',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: .82),
                            ),
                          ),
                        ],
                      ),
                    ),
                    crossFadeState: _compactFooterExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 220),
                    sizeCurve: Curves.easeOutCubic,
                    firstCurve: Curves.easeOut,
                    secondCurve: Curves.easeIn,
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: denseDesktop ? 20 : 24,
              vertical: denseDesktop ? 8 : 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildFooterBrand(theme, dense: denseDesktop),
                    ),
                    SizedBox(width: denseDesktop ? 10 : 14),
                    Expanded(
                      flex: 2,
                      child: _buildFooterQuickLinks(theme, dense: denseDesktop),
                    ),
                    SizedBox(width: denseDesktop ? 10 : 14),
                    Expanded(
                      flex: 2,
                      child: _buildFooterHighlights(theme, dense: denseDesktop),
                    ),
                  ],
                ),
                SizedBox(height: denseDesktop ? 8 : 10),
                Divider(color: Colors.white.withValues(alpha: .2), height: 1),
                SizedBox(height: denseDesktop ? 6 : 8),
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

  Widget _buildFooterBrand(ThemeData theme, {bool dense = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: dense ? 36 : 42,
              height: dense ? 36 : 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.all(dense ? 6 : 7),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            Text(
              'Legebere',
              style:
                  (dense
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.titleLarge)
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
            ),
          ],
        ),
        SizedBox(height: dense ? 6 : 8),
        Text(
          context.tr(
            'Find quality livestock, compare prices, and transact confidently with trusted sellers.',
          ),
          maxLines: dense ? 1 : null,
          overflow: dense ? TextOverflow.ellipsis : TextOverflow.visible,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: .9),
            height: dense ? 1.25 : 1.4,
          ),
        ),
        SizedBox(height: dense ? 8 : 10),
        Wrap(
          spacing: dense ? 6 : 8,
          runSpacing: dense ? 6 : 8,
          children: dense
              ? [
                  _buildFooterStat('5k+', 'Listings', compact: true),
                  _buildFooterStat('99%', 'Verified sellers', compact: true),
                ]
              : [
                  _buildFooterStat('5k+', 'Listings'),
                  _buildFooterStat('1k+', 'Active buyers'),
                  _buildFooterStat('99%', 'Verified sellers'),
                ],
        ),
      ],
    );
  }

  Widget _buildFooterQuickLinks(ThemeData theme, {bool dense = false}) {
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
        SizedBox(height: dense ? 6 : 8),
        _buildFooterLink(
          'Browse listings',
          () => _handleIndexTap(0),
          dense: dense,
        ),
        _buildFooterLink('Back to top', _scrollHomeToTop, dense: dense),
        _buildFooterLink('Favorites', () => _handleIndexTap(1), dense: dense),
        _buildFooterLink('Vet care', () => _handleIndexTap(2), dense: dense),
        if (!dense)
          _buildFooterLink(
            'E-learning',
            () => _handleIndexTap(3),
            dense: dense,
          ),
        _buildFooterLink('Sell livestock', _handleFabPressed, dense: dense),
      ],
    );
  }

  Widget _buildFooterHighlights(ThemeData theme, {bool dense = false}) {
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
        SizedBox(height: dense ? 6 : 8),
        if (!dense)
          Text(
            'Market updates, expert vet support, and finance resources in one place.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: .9),
              height: 1.4,
            ),
          ),
        SizedBox(height: dense ? 6 : 10),
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

  Widget _buildFooterLink(
    String label,
    VoidCallback onTap, {
    bool dense = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 0 : 2),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 0, vertical: dense ? 4 : 6),
          foregroundColor: Colors.white.withValues(alpha: .95),
          minimumSize: Size(0, dense ? 30 : 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
        ),
        onPressed: onTap,
        icon: Icon(Icons.arrow_right_alt_rounded, size: dense ? 16 : 18),
        label: Text(label),
      ),
    );
  }

  Widget _buildFooterStat(String value, String label, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
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
              fontSize: compact ? 11 : 12,
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
