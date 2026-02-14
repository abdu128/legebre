import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/vet_drug.dart';
import '../services/api_exception.dart';
import '../state/app_state.dart';

class VetDrugDetailScreen extends StatefulWidget {
  const VetDrugDetailScreen({super.key, required this.item});

  final VetDrug item;

  @override
  State<VetDrugDetailScreen> createState() => _VetDrugDetailScreenState();
}

class _VetDrugDetailScreenState extends State<VetDrugDetailScreen> {
  late VetDrug _drug;
  bool _isLoading = false;
  int _activePhoto = 0;
  bool _loadingContact = true;
  Map<String, dynamic>? _contact;
  bool _statusBusy = false;
  bool _isSold = false;

  @override
  void initState() {
    super.initState();
    _drug = widget.item;
    _isSold = _statusIsSold(_drug.status);
    _fetchDetails();
    _loadContact();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final api = context.read<AppState>().api;
      final fresh = await api.getVetDrug(widget.item.id);
      if (!mounted) return;
      setState(() {
        _drug = fresh;
        _isSold = _statusIsSold(fresh.status);
      });
      _loadContact();
    } catch (_) {
      // ignore, we keep showing the initial payload
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      final failureMessage = channel == 'CALL'
          ? context.tr('Unable to open dialer')
          : context.tr('Unable to open WhatsApp');
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  Future<bool> _logContactEvent(String channel) async {
    final api = context.read<AppState>().api;
    try {
      await api.logContactEvent(
        resourceType: 'VET_DRUG',
        resourceId: _drug.id,
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
                'Session expired. Please log in again to contact pharmacists.',
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

  Future<void> _changeStatus(bool sold) async {
    if (_statusBusy) return;
    setState(() {
      _statusBusy = true;
      _isSold = sold;
      _drug = _drug.copyWith(status: sold ? 'SOLD' : 'AVAILABLE');
    });

    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<AppState>().api;
    try {
      await api.changeVetDrugStatus(_drug.id, sold ? 'SOLD' : 'AVAILABLE');
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
      setState(() {
        _isSold = !sold;
        _drug = _drug.copyWith(status: _isSold ? 'SOLD' : 'AVAILABLE');
      });
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      setState(() {
        _isSold = !sold;
        _drug = _drug.copyWith(status: _isSold ? 'SOLD' : 'AVAILABLE');
      });
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Failed to update status'))),
      );
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Future<void> _loadContact() async {
    setState(() => _loadingContact = true);
    try {
      final contact = await context.read<AppState>().api.getVetDrugContact(
        _drug.id,
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
    if (_drug.photos.isNotEmpty) return _drug.photos;
    if (_drug.primaryPhoto != null) return [_drug.primaryPhoto!];
    return const [];
  }

  bool _statusIsSold(String? status) {
    if (status == null) return false;
    return status.trim().toUpperCase() == 'SOLD';
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: context.l10n.localeTag,
      decimalDigits: 0,
      symbol: 'ETB ',
    );
    final priceText = _drug.price != null
        ? formatter.format(_drug.price)
        : context.tr('Contact for price');
    final user = context.watch<AppState>().user;
    final isOwner = user?.id == _drug.sellerId;
    final statusLabel = _isSold ? 'SOLD' : (_drug.status ?? 'AVAILABLE');
    String extractContact(String? value, String key) {
      final direct = value?.trim() ?? '';
      if (direct.isNotEmpty) return direct;
      return _contact?[key]?.toString().trim() ?? '';
    }

    final resolvedSellerName = extractContact(_drug.sellerName, 'sellerName');
    final sellerName = resolvedSellerName.isNotEmpty
        ? resolvedSellerName
        : context.tr('Supplier');
    final sellerPhone = extractContact(_drug.contactPhone, 'phone');
    final sellerWhatsapp = extractContact(_drug.contactWhatsapp, 'whatsapp');
    final hasDirectContact =
        sellerPhone.isNotEmpty || sellerWhatsapp.isNotEmpty;
    final contactHint = hasDirectContact
        ? context.tr('Contact seller')
        : context.tr('Contact coming soon');
    final avatarLetter = sellerName.isNotEmpty
        ? sellerName[0].toUpperCase()
        : 'P';

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
                            tag: 'vet-drug-${_drug.id}',
                            child: PageView.builder(
                              itemCount: _photos.length,
                              onPageChanged: (value) {
                                setState(() => _activePhoto = value);
                              },
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
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_photos.length, (index) {
                          final isActive = index == _activePhoto;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: .4),
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
                              _drug.name,
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
                      _StatusChip(label: statusLabel),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_drug.description != null &&
                      _drug.description!.isNotEmpty)
                    Text(
                      _drug.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 24),
                  _InfoGrid(
                    items: [
                      _InfoTile(
                        label: 'Category',
                        value: _drug.category ?? 'General',
                      ),
                      if (_drug.unit != null && _drug.unit!.isNotEmpty)
                        _InfoTile(label: 'Unit', value: _drug.unit!),
                      if (_drug.stock != null)
                        _InfoTile(
                          label: 'In stock',
                          value: _drug.stock.toString(),
                        ),
                      if (_drug.manufacturer != null &&
                          _drug.manufacturer!.isNotEmpty)
                        _InfoTile(
                          label: 'Manufacturer',
                          value: _drug.manufacturer!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if ((_drug.usage ?? '').isNotEmpty ||
                      (_drug.dosage ?? '').isNotEmpty)
                    _DetailCard(
                      title: 'Usage & dosage',
                      children: [
                        if ((_drug.usage ?? '').isNotEmpty)
                          _DetailRow(
                            icon: Icons.medical_information,
                            label: 'Usage instructions',
                            value: _drug.usage!,
                          ),
                        if ((_drug.dosage ?? '').isNotEmpty)
                          _DetailRow(
                            icon: Icons.monitor_weight,
                            label: 'Dosage guidance',
                            value: _drug.dosage!,
                          ),
                        if ((_drug.storage ?? '').isNotEmpty)
                          _DetailRow(
                            icon: Icons.ac_unit,
                            label: 'Storage',
                            value: _drug.storage!,
                          ),
                      ],
                    ),
                  if ((_drug.deliveryRegions ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: _DetailCard(
                        title: 'Delivery',
                        children: [
                          _DetailRow(
                            icon: Icons.local_shipping,
                            label: 'Regions served',
                            value: _drug.deliveryRegions!,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  _DetailCard(
                    title: 'Pharmacist contact',
                    children: [
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
                                  sellerName,
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
                          if (_loadingContact)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: sellerPhone.isEmpty
                                  ? null
                                  : () => _handleContactAction(
                                      channel: 'CALL',
                                      missingLabel: 'phone',
                                      value: sellerPhone,
                                    ),
                              icon: const Icon(Icons.call),
                              label: Text(context.tr('Call')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: sellerWhatsapp.isEmpty
                                  ? null
                                  : () => _handleContactAction(
                                      channel: 'WHATSAPP',
                                      missingLabel: 'WhatsApp',
                                      value: sellerWhatsapp,
                                    ),
                              icon: const Icon(Icons.chat_rounded),
                              label: Text(context.tr('WhatsApp')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isOwner)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: _DetailCard(
                        title: context.tr('Seller actions'),
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _isSold,
                            onChanged: _statusBusy
                                ? null
                                : (value) => _changeStatus(value),
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
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
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
        child: Icon(Icons.vaccines, size: 48, color: Colors.grey),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.background,
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

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
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
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
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
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
