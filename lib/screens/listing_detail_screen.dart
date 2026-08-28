import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/animal.dart';
import '../services/api_exception.dart';
import '../state/app_state.dart';
import '../utils/responsive.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.item});

  final Animal item;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late bool _isFavorite;
  late bool _isSold;
  late final PageController _controller;
  int _currentPage = 0;
  bool _favoriteBusy = false;
  bool _statusBusy = false;
  bool _loadingContact = true;
  Map<String, dynamic>? _contact;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.item.isFavorite;
    _isSold = widget.item.status == 'SOLD';
    _controller = PageController();
    _loadContact();
  }

  Future<void> _loadContact() async {
    setState(() => _loadingContact = true);
    try {
      final api = context.read<AppState>().api;
      final contact = await api.getAnimalContact(widget.item.id);
      if (!mounted) return;
      setState(() {
        _contact = contact;
        _loadingContact = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingContact = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) return;
    setState(() {
      _favoriteBusy = true;
      _isFavorite = !_isFavorite;
    });
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<AppState>().api;

    try {
      if (_isFavorite) {
        await api.addFavorite(widget.item.id);
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr('Added to favorites'))),
        );
      } else {
        await api.removeFavorite(widget.item.id);
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr('Removed from favorites'))),
        );
      }
    } on ApiException catch (error) {
      setState(() => _isFavorite = !_isFavorite);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      setState(() => _isFavorite = !_isFavorite);
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Could not update favorites'))),
      );
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Future<void> _updateStatus(bool sold) async {
    if (_statusBusy) return;
    setState(() {
      _statusBusy = true;
      _isSold = sold;
    });
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<AppState>().api;
    try {
      await api.changeAnimalStatus(widget.item.id, sold ? 'SOLD' : 'AVAILABLE');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            sold
                ? context.tr('Listing marked as sold')
                : context.tr('Listing available again'),
          ),
        ),
      );
    } on ApiException catch (error) {
      setState(() => _isSold = !sold);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      setState(() => _isSold = !sold);
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Failed to update status'))),
      );
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Future<void> _handleContactAction({
    required String channel,
    required String missingLabel,
    required String? value,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      final missingMessage = missingLabel.toLowerCase() == 'phone'
          ? context.tr('No phone contact provided')
          : context.tr('No WhatsApp contact provided');
      messenger.showSnackBar(SnackBar(content: Text(missingMessage)));
      return;
    }

    final canProceed = await _logContactEvent(channel);
    if (!canProceed || !mounted) return;

    final launched = channel == 'CALL'
        ? await _launchPhone(trimmed)
        : await _launchWhatsapp(trimmed);

    if (!launched) {
      final failureMessage = missingLabel.toLowerCase() == 'phone'
          ? context.tr('Unable to open dialer')
          : context.tr('Unable to open WhatsApp');
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  Future<bool> _logContactEvent(String channel) async {
    final api = context.read<AppState>().api;
    try {
      await api.logContactEvent(
        resourceType: 'ANIMAL',
        resourceId: widget.item.id,
        channel: channel,
      );
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        if (!mounted) return false;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Session expired. Please log in again to contact sellers.',
              ),
            ),
          ),
        );
        await context.read<AppState>().logout();
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    return launchUrl(uri);
  }

  Future<bool> _launchWhatsapp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return false;
    final uri = Uri.parse('https://wa.me/$digits');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String? _sanitizeContact(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: context.l10n.localeTag,
      symbol: 'ETB ',
      decimalDigits: 0,
    );
    final photos = widget.item.displayPhotos.isEmpty
        ? [widget.item.coverPhoto]
      : widget.item.displayPhotos;
    final user = context.watch<AppState>().user;
    final isOwner = user?.id == widget.item.sellerId;

    final sellerName =
        widget.item.sellerName ??
        _contact?['sellerName']?.toString() ??
        context.tr('Verified seller');
    final sellerPhone = _sanitizeContact(
      widget.item.sellerPhone ?? _contact?['phone']?.toString(),
    );
    final sellerWhatsapp = _sanitizeContact(
      widget.item.sellerWhatsapp ?? _contact?['whatsapp']?.toString(),
    );
    final hasDirectContact = sellerPhone != null || sellerWhatsapp != null;
    final contactHint = hasDirectContact
        ? context.tr('Contact seller')
        : context.tr('Contact coming soon');

    final viewportWidth = MediaQuery.of(context).size.width;
    final isWideDesktop = kIsWeb && viewportWidth >= 980;

    Widget buildImageCarousel({double? height, BorderRadius? borderRadius}) {
      final radius = borderRadius ?? const BorderRadius.vertical(bottom: Radius.circular(28));
      return Stack(
        children: [
          ClipRRect(
            borderRadius: radius,
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (index) => setState(() {
                _currentPage = index;
              }),
              itemCount: photos.length,
              itemBuilder: (_, index) => Hero(
                tag: index == 0
                    ? 'animal-${widget.item.id}'
                    : 'animal-${widget.item.id}-$index',
                child: Image.network(
                  photos[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.background,
                    child: const Icon(
                      Icons.image_not_supported_rounded,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Bottom gradient for readability
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 80,
            child: ClipRRect(
              borderRadius: radius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .4),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Back button
          Positioned(
            top: 12,
            left: 12,
            child: Material(
              color: Colors.white.withValues(alpha: .9),
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_rounded, size: 22),
                ),
              ),
            ),
          ),
          // Favorite button
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.white.withValues(alpha: .9),
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _favoriteBusy ? null : _toggleFavorite,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    _isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: AppColors.accentRed,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          // Page dots
          if (photos.length > 1)
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  photos.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == index ? 20 : 8,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    Widget buildDetailsContent() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price + title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatter.format(widget.item.price),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryGreen,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (widget.item.breed?.isNotEmpty ?? false)
                          ? widget.item.breed!
                          : widget.item.animalType,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.3,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.item.location ??
                                context.tr(
                                  'Location not provided',
                                ),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(status: widget.item.status),
            ],
          ),

          const SizedBox(height: 20),

          // Info chips row
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.pets_rounded,
                label: widget.item.animalType,
              ),
              if (widget.item.breed != null)
                _InfoChip(
                  icon: Icons.category_rounded,
                  label: widget.item.breed!,
                ),
              if (widget.item.weight != null)
                _InfoChip(
                  icon: Icons.monitor_weight_rounded,
                  label:
                      '${widget.item.weight!.toStringAsFixed(0)} kg',
                ),
              if (widget.item.age != null)
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: widget.item.age!,
                ),
            ],
          ),

          // Description
          if ((widget.item.description?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Text(
                widget.item.description!,
                style: TextStyle(
                  height: 1.6,
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Seller card
          _SectionCard(
            title: context.tr('Seller profile'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryGreen,
                            AppColors.secondaryGreen,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          sellerName.isNotEmpty
                              ? sellerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                sellerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              if (widget.item.sellerVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 16,
                                  color: AppColors.primaryGreen,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            contactHint,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_loadingContact)
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: sellerPhone == null
                            ? null
                            : () => _handleContactAction(
                                channel: 'CALL',
                                missingLabel: 'phone',
                                value: sellerPhone,
                              ),
                        icon: const Icon(Icons.call_rounded),
                        label: Text(context.tr('Call')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: sellerWhatsapp == null
                            ? null
                            : () => _handleContactAction(
                                channel: 'WHATSAPP',
                                missingLabel: 'WhatsApp',
                                value: sellerWhatsapp,
                              ),
                        icon: const Icon(Icons.chat_rounded),
                        label: Text(context.tr('WhatsApp')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          side: const BorderSide(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (isOwner) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: context.tr('Seller actions'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: _isSold,
                    onChanged: _statusBusy ? null : _updateStatus,
                    title: Text(context.tr('Mark as sold')),
                    subtitle: Text(
                      context.tr(
                        'Buyers will see the listing as unavailable.',
                      ),
                    ),
                  ),
                  if (_statusBusy)
                    const LinearProgressIndicator(minHeight: 2),
                ],
              ),
            ),
          ],
        ],
      );
    }

    // --- Wide desktop: side-by-side layout ---
    if (isWideDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Image carousel
                    Expanded(
                      flex: 5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height - 100,
                          child: buildImageCarousel(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    // Right: Details
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: buildDetailsContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // --- Mobile / narrow: stacked layout ---
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
            child: Column(
              children: [
                SizedBox(
                  height: 340,
                  child: buildImageCarousel(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    child: buildDetailsContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isAvailable = status.toUpperCase() == 'AVAILABLE';
    final color = isAvailable ? AppColors.primaryGreen : AppColors.accentOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}
