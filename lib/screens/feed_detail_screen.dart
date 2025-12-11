import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../models/feed_item.dart';
import '../services/api_exception.dart';
import '../state/app_state.dart';

class FeedDetailScreen extends StatefulWidget {
  const FeedDetailScreen({super.key, required this.item});

  final FeedItem item;

  @override
  State<FeedDetailScreen> createState() => _FeedDetailScreenState();
}

class _FeedDetailScreenState extends State<FeedDetailScreen> {
  late FeedItem _feed;
  bool _isLoading = false;
  int _photoIndex = 0;
  bool _loadingContact = true;
  Map<String, dynamic>? _contact;

  @override
  void initState() {
    super.initState();
    _feed = widget.item;
    _fetchDetails();
    _loadContact();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final api = context.read<AppState>().api;
      final fresh = await api.getFeed(widget.item.id);
      if (!mounted) return;
      setState(() => _feed = fresh);
      _loadContact();
    } catch (_) {
      // Keep showing cached data if network fails.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadContact() async {
    setState(() => _loadingContact = true);
    try {
      final contact = await context.read<AppState>().api.getFeedContact(
        _feed.id,
      );
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

  List<String> get _photos {
    if (_feed.photos.isNotEmpty) return _feed.photos;
    if (_feed.primaryPhoto != null) return [_feed.primaryPhoto!];
    return const [];
  }

  Future<void> _handleContact(String channel, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No ${channel == 'CALL' ? 'phone' : 'WhatsApp'} contact provided',
          ),
        ),
      );
      return;
    }

    final canProceed = await _logContactEvent(channel);
    if (!canProceed || !mounted) return;

    final launched = channel == 'CALL'
        ? await _launchPhone(trimmed)
        : await _launchWhatsapp(trimmed);
    if (!launched && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open ${channel == 'CALL' ? 'dialer' : 'WhatsApp'}',
          ),
        ),
      );
    }
  }

  Future<bool> _logContactEvent(String channel) async {
    final api = context.read<AppState>().api;
    try {
      await api.logContactEvent(
        resourceType: 'FEED',
        resourceId: _feed.id,
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
              'Session expired. Please log in again to contact suppliers.',
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
    final currency = NumberFormat.currency(
      locale: 'en_ET',
      decimalDigits: 0,
      symbol: 'ETB ',
    );
    final priceText = _feed.price != null
        ? currency.format(_feed.price)
        : 'Contact seller';

    String extractContact(String? value, String fallbackKey) {
      final direct = value?.trim() ?? '';
      if (direct.isNotEmpty) return direct;
      final contactValue = _contact?[fallbackKey]?.toString().trim() ?? '';
      return contactValue;
    }

    final sellerName = extractContact(_feed.sellerName, 'sellerName');
    final sellerPhone = extractContact(_feed.sellerPhone, 'phone');
    final sellerWhatsapp = extractContact(_feed.sellerWhatsapp, 'whatsapp');
    final hasSellerInfo =
        sellerName.isNotEmpty ||
        sellerPhone.isNotEmpty ||
        sellerWhatsapp.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Positioned.fill(
                    child: _photos.isNotEmpty
                        ? Hero(
                            tag: 'feed-${_feed.id}',
                            child: PageView.builder(
                              itemCount: _photos.length,
                              onPageChanged: (index) => setState(() {
                                _photoIndex = index;
                              }),
                              itemBuilder: (_, index) {
                                final photo = _photos[index];
                                return Image.network(
                                  photo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _placeholder(),
                                );
                              },
                            ),
                          )
                        : _placeholder(),
                  ),
                  if (_photos.length > 1)
                    Positioned(
                      bottom: 18,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_photos.length, (index) {
                          final isActive = index == _photoIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: .45),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                              _feed.name,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              priceText,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusChip(label: _feed.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((_feed.feedType ?? '').isNotEmpty)
                        _InfoPill(icon: Icons.category, label: _feed.feedType!),
                      if ((_feed.animalType ?? '').isNotEmpty)
                        _InfoPill(icon: Icons.pets, label: _feed.animalType!),
                      if ((_feed.brand ?? '').isNotEmpty)
                        _InfoPill(icon: Icons.factory, label: _feed.brand!),
                      if ((_feed.location ?? '').isNotEmpty)
                        _InfoPill(
                          icon: Icons.location_pin,
                          label: _feed.location!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if ((_feed.description ?? '').isNotEmpty)
                    Text(
                      _feed.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 24),
                  _InfoGrid(
                    items: [
                      if (_feed.weight != null)
                        _InfoTile(
                          label: 'Weight',
                          value:
                              '${_feed.weight!.toStringAsFixed(_feed.weight! % 1 == 0 ? 0 : 1)} kg',
                        ),
                      if (_feed.unit != null && _feed.unit!.isNotEmpty)
                        _InfoTile(label: 'Unit', value: _feed.unit!),
                      if (_feed.expiryDate != null)
                        _InfoTile(
                          label: 'Expiry date',
                          value: DateFormat.yMMMMd().format(_feed.expiryDate!),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (hasSellerInfo)
                    _SellerCard(
                      displayName: sellerName,
                      phone: sellerPhone,
                      whatsapp: sellerWhatsapp,
                      isLoading: _loadingContact,
                      onCallTapped: (value) => _handleContact('CALL', value),
                      onWhatsappTapped: (value) =>
                          _handleContact('WHATSAPP', value),
                    ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toUpperCase();
    final isAvailable =
        normalized.contains('AVAILABLE') || normalized.contains('LOW');
    final color = isAvailable ? AppColors.primaryGreen : AppColors.accentRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<_InfoTile> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 12, runSpacing: 12, children: items);
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              letterSpacing: .3,
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({
    required this.displayName,
    required this.phone,
    required this.whatsapp,
    this.isLoading = false,
    this.onCallTapped,
    this.onWhatsappTapped,
  });

  final String displayName;
  final String phone;
  final String whatsapp;
  final bool isLoading;
  final Future<void> Function(String value)? onCallTapped;
  final Future<void> Function(String value)? onWhatsappTapped;

  @override
  Widget build(BuildContext context) {
    final name = displayName.trim().isNotEmpty
        ? displayName.trim()
        : 'Supplier';
    final avatarLetter = name[0].toUpperCase();
    final contactHint = phone.isNotEmpty
        ? phone
        : (whatsapp.isNotEmpty ? whatsapp : 'Contact coming soon');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Supplier profile',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryGreen,
                child: Text(
                  avatarLetter,
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
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contactHint,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: phone.isEmpty || onCallTapped == null
                      ? null
                      : () => onCallTapped!(phone),
                  icon: const Icon(Icons.call),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: whatsapp.isEmpty || onWhatsappTapped == null
                      ? null
                      : () => onWhatsappTapped!(whatsapp),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
