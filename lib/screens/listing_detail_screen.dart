import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../models/animal.dart';
import '../services/api_exception.dart';
import '../state/app_state.dart';

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
          const SnackBar(content: Text('Added to favorites')),
        );
      } else {
        await api.removeFavorite(widget.item.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Removed from favorites')),
        );
      }
    } on ApiException catch (error) {
      setState(() => _isFavorite = !_isFavorite);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      setState(() => _isFavorite = !_isFavorite);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update favorites')),
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
            sold ? 'Listing marked as sold' : 'Listing available again',
          ),
        ),
      );
    } on ApiException catch (error) {
      setState(() => _isSold = !sold);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      setState(() => _isSold = !sold);
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to update status')),
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
      messenger.showSnackBar(
        SnackBar(content: Text('No $missingLabel contact provided')),
      );
      return;
    }

    final canProceed = await _logContactEvent(channel);
    if (!canProceed || !mounted) return;

    final launched = channel == 'CALL'
        ? await _launchPhone(trimmed)
        : await _launchWhatsapp(trimmed);

    if (!launched) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to open $missingLabel app')),
      );
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
          const SnackBar(
            content: Text(
              'Session expired. Please log in again to contact sellers.',
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

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'en_ET',
      symbol: 'ETB ',
      decimalDigits: 0,
    );
    final photos = widget.item.photos.isEmpty
        ? [widget.item.coverPhoto]
        : widget.item.photos;
    final user = context.watch<AppState>().user;
    final isOwner = user?.id == widget.item.sellerId;

    final sellerName =
        widget.item.sellerName ??
        _contact?['sellerName']?.toString() ??
        'Verified seller';
    final sellerPhone =
        widget.item.sellerPhone ?? _contact?['phone']?.toString();
    final sellerWhatsapp =
        widget.item.sellerWhatsapp ?? _contact?['whatsapp']?.toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 320,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _controller,
                    onPageChanged: (index) => setState(() {
                      _currentPage = index;
                    }),
                    itemCount: photos.length,
                    itemBuilder: (_, index) => Image.network(
                      photos[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        onPressed: _favoriteBusy ? null : _toggleFavorite,
                        icon: Icon(
                          _isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border_outlined,
                          color: AppColors.accentRed,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        photos.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 12 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (widget.item.breed?.isNotEmpty ?? false)
                                    ? widget.item.breed!
                                    : widget.item.animalType,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_pin,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      widget.item.location ??
                                          'Location not provided',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .05),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Text(
                            widget.item.status,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _InfoChip(
                          icon: Icons.pets,
                          label: widget.item.animalType,
                        ),
                        if (widget.item.breed != null)
                          _InfoChip(
                            icon: Icons.category_rounded,
                            label: widget.item.breed!,
                          ),
                        if (widget.item.weight != null)
                          _InfoChip(
                            icon: Icons.monitor_weight,
                            label:
                                '${widget.item.weight!.toStringAsFixed(0)} kg',
                          ),
                        if (widget.item.age != null)
                          _InfoChip(
                            icon: Icons.timer_outlined,
                            label: widget.item.age!,
                          ),
                      ],
                    ),
                    if ((widget.item.description?.isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(widget.item.description!),
                      ),
                    const SizedBox(height: 24),
                    _SectionCard(
                      title: 'Seller profile',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: AppColors.primaryGreen,
                                child: Text(
                                  sellerName.isNotEmpty
                                      ? sellerName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sellerName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      sellerPhone ??
                                          sellerWhatsapp ??
                                          'Contact coming soon',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_loadingContact)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                                  icon: const Icon(Icons.call),
                                  label: const Text('Call'),
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
                                  label: const Text('WhatsApp'),
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
                        title: 'Seller actions',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              value: _isSold,
                              onChanged: _statusBusy ? null : _updateStatus,
                              title: const Text('Mark as sold'),
                              subtitle: const Text(
                                'Buyers will see the listing as unavailable.',
                              ),
                            ),
                            if (_statusBusy)
                              const LinearProgressIndicator(minHeight: 2),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: .2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
