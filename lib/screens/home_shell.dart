import 'dart:async';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const _facebookUrl =
    'https://www.facebook.com/share/18rXxQkpNC/';
  static const _instagramUrl =
    'https://www.instagram.com/legebere?igsh=MW1pMGQ0NThyNmd4ZQ==';
  static const _tiktokUrl =
    'https://www.tiktok.com/@legebere?_r=1&_t=ZS-96bKL6ZyFCX';
  static const _youtubeUrl =
    'https://youtube.com/@legebere?si=c-3J5oj3jVBXIcVt';
  static const _googlePlayUrl =
    'https://play.google.com/store/apps/details?id=com.legebere.marketplace&pcampaignid=web_share';

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

  Future<void> _launchExternalUrl(String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Could not open link'))),
      );
    }
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

  Future<void> _openLanguagePicker() async {
    final appState = context.read<AppState>();
    final currentCode = appState.locale.languageCode;

    final selectedCode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Select language'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    onChanged: (value) {
                      Navigator.of(sheetContext).pop(value);
                    },
                    title: Text(label),
                    contentPadding: EdgeInsets.zero,
                  );
                }),
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

      if (value == 'language') {
        await _openLanguagePicker();
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
        PopupMenuItem<String>(
          value: 'language',
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: .12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  Icons.language_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('Change language'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
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
                          _buildCompactFooterInfoRow(
                            icon: Icons.location_on_outlined,
                            text:
                                'Addis Ababa, Ethiopia',
                            theme: theme,
                          ),
                          const SizedBox(height: 6),
                          _buildCompactFooterInfoRow(
                            icon: Icons.phone_outlined,
                            text: '+251 90 479 5093',
                            theme: theme,
                          ),
                          const SizedBox(height: 6),
                          _buildCompactFooterInfoRow(
                            icon: Icons.mail_outline_rounded,
                            text: 'support@legebere.com',
                            theme: theme,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildCompactFooterColumn(
                                  title: 'My account',
                                  items: [
                                    ('Manage account', () async {
                                      final appState = context.read<AppState>();
                                      if (!appState.isAuthenticated) {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const AuthScreen(),
                                          ),
                                        );
                                        return;
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Profile screen coming soon'),
                                        ),
                                      );
                                    }),
                                    ('Products', () async {
                                      await _handleIndexTap(0);
                                    }),
                                  ],
                                  theme: theme,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildCompactFooterColumn(
                                  title: 'Helps',
                                  items: [
                                    ('Contact us', () async {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Contact support@legebere.com'),
                                        ),
                                      );
                                    }),
                                    ('FAQs', () async {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('FAQs coming soon')),
                                      );
                                    }),
                                    ('Privacy policy', () async {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Privacy policy coming soon'),
                                        ),
                                      );
                                    }),
                                  ],
                                  theme: theme,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildCompactFooterColumn(
                                  title: 'Other',
                                  items: [
                                    ('About', () async {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('About page coming soon')),
                                      );
                                    }),
                                    ('Login', () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const AuthScreen(),
                                        ),
                                      );
                                    }),
                                    ('Register', () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const AuthScreen(),
                                        ),
                                      );
                                    }),
                                  ],
                                  theme: theme,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildCompactFooterSocialButton(
                                icon: FontAwesomeIcons.facebookF,
                                label: 'Facebook',
                                onTap: () async {
                                  await _launchExternalUrl(_facebookUrl);
                                },
                              ),
                              _buildCompactFooterSocialButton(
                                icon: FontAwesomeIcons.instagram,
                                label: 'Instagram',
                                onTap: () async {
                                  await _launchExternalUrl(_instagramUrl);
                                },
                              ),
                              _buildCompactFooterSocialButton(
                                icon: FontAwesomeIcons.tiktok,
                                label: 'TikTok',
                                onTap: () async {
                                  await _launchExternalUrl(_tiktokUrl);
                                },
                              ),
                              _buildCompactFooterSocialButton(
                                icon: FontAwesomeIcons.youtube,
                                label: 'YouTube',
                                onTap: () async {
                                  await _launchExternalUrl(_youtubeUrl);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildCompactStoreBadge(
                                icon: FontAwesomeIcons.apple,
                                topText: 'Download on the',
                                bottomText: 'App Store',
                                onTap: () async {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('App Store coming soon')),
                                  );
                                },
                              ),
                              _buildCompactStoreBadge(
                                icon: FontAwesomeIcons.googlePlay,
                                topText: 'Get it on',
                                bottomText: 'Google Play',
                                onTap: () async {
                                  await _launchExternalUrl(_googlePlayUrl);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
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

  Widget _buildCompactFooterSocialButton({
    required IconData icon,
    required String label,
    required Future<void> Function() onTap,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          onTap();
        },
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .3)),
          ),
          child: Center(
            child: FaIcon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStoreBadge({
    required IconData icon,
    required String topText,
    required String bottomText,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        onTap();
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 158),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  topText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    height: 1.1,
                  ),
                ),
                Text(
                  bottomText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactFooterInfoRow({
    required IconData icon,
    required String text,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.white.withValues(alpha: .86)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: .88),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactFooterColumn({
    required String title,
    required List<(String, Future<void> Function())> items,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        ...items.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 3),
                minimumSize: const Size(0, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
                foregroundColor: Colors.white.withValues(alpha: .9),
              ),
              onPressed: () {
                entry.$2();
              },
              child: Text(
                entry.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ],
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
        if (!dense) ...[
          const SizedBox(height: 10),
          _buildCompactFooterInfoRow(
            icon: Icons.location_on_outlined,
            text:
                'Addis Ababa, Ethiopia • Shimex Estate, Lugbe, FCT Nigeria',
            theme: theme,
          ),
          const SizedBox(height: 6),
          _buildCompactFooterInfoRow(
            icon: Icons.phone_outlined,
            text: '+251 90 479 5093 • +234 8108597000',
            theme: theme,
          ),
          const SizedBox(height: 6),
          _buildCompactFooterInfoRow(
            icon: Icons.mail_outline_rounded,
            text: 'support@legebere.com',
            theme: theme,
          ),
        ],
      ],
    );
  }

  Widget _buildFooterQuickLinks(ThemeData theme, {bool dense = false}) {
    if (dense) {
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
          _buildFooterLink(
            'Favorites',
            () => _handleIndexTap(1),
            dense: dense,
          ),
          _buildFooterLink('Vet care', () => _handleIndexTap(2), dense: dense),
          _buildFooterLink('Sell livestock', _handleFabPressed, dense: dense),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Useful links',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFooterDesktopLinkColumn(
                title: 'My account',
                items: [
                  ('Manage account', () {
                    final appState = context.read<AppState>();
                    if (!appState.isAuthenticated) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      );
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile screen coming soon')),
                    );
                  }),
                  ('Products', () => _handleIndexTap(0)),
                ],
                theme: theme,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFooterDesktopLinkColumn(
                title: 'Helps',
                items: [
                  ('Contact us', () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contact support@legebere.com')),
                    );
                  }),
                  ('FAQs', () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('FAQs coming soon')),
                    );
                  }),
                  ('Terms', () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Terms coming soon')),
                    );
                  }),
                  ('Privacy policy', () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Privacy policy coming soon')),
                    );
                  }),
                ],
                theme: theme,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFooterDesktopLinkColumn(
                title: 'Other',
                items: [
                  ('About', () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('About page coming soon')),
                    );
                  }),
                  ('Login', () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  }),
                  ('Register', () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  }),
                ],
                theme: theme,
              ),
            ),
          ],
        ),
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
          runSpacing: 8,
          children: [
            _buildCompactFooterSocialButton(
              icon: FontAwesomeIcons.facebookF,
              label: 'Facebook',
              onTap: () async {
                await _launchExternalUrl(_facebookUrl);
              },
            ),
            _buildCompactFooterSocialButton(
              icon: FontAwesomeIcons.instagram,
              label: 'Instagram',
              onTap: () async {
                await _launchExternalUrl(_instagramUrl);
              },
            ),
            _buildCompactFooterSocialButton(
              icon: FontAwesomeIcons.tiktok,
              label: 'TikTok',
              onTap: () async {
                await _launchExternalUrl(_tiktokUrl);
              },
            ),
            _buildCompactFooterSocialButton(
              icon: FontAwesomeIcons.youtube,
              label: 'YouTube',
              onTap: () async {
                await _launchExternalUrl(_youtubeUrl);
              },
            ),
          ],
        ),
        if (!dense) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCompactStoreBadge(
                icon: FontAwesomeIcons.apple,
                topText: 'Download on the',
                bottomText: 'App Store',
                onTap: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('App Store coming soon')),
                  );
                },
              ),
              _buildCompactStoreBadge(
                icon: FontAwesomeIcons.googlePlay,
                topText: 'Get it on',
                bottomText: 'Google Play',
                onTap: () async {
                  await _launchExternalUrl(_googlePlayUrl);
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFooterDesktopLinkColumn({
    required String title,
    required List<(String, VoidCallback)> items,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        ...items.map(
          (entry) => TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
              foregroundColor: Colors.white.withValues(alpha: .9),
            ),
            onPressed: entry.$2,
            child: Text(
              entry.$1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
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
