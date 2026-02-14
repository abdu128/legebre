import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../models/vet_drug.dart';
import '../l10n/app_localizations.dart';

class VetDrugCard extends StatelessWidget {
  const VetDrugCard({super.key, required this.item, this.onTap});

  final VetDrug item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.compactCurrency(
      locale: context.l10n.localeTag,
      decimalDigits: 0,
      symbol: 'ETB ',
    );
    final priceText = item.price != null
        ? formatter.format(item.price)
        : context.tr('Contact for price');
    final status = (item.status ?? '').trim();
    final hasStatus = status.isNotEmpty;
    final friendlyStatus = hasStatus
        ? status
              .replaceAll('_', ' ')
              .toLowerCase()
              .split(' ')
              .map(
                (word) => word.isEmpty
                    ? word
                    : '${word[0].toUpperCase()}${word.substring(1)}',
              )
              .join(' ')
        : '';
    final delivery = (item.deliveryRegions ?? '').trim();
    final summary = (item.description ?? '').trim();
    final category = (item.category ?? '').trim();
    final manufacturer = (item.manufacturer ?? '').trim();
    final unit = (item.unit ?? '').trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: item.primaryPhoto != null
                          ? Hero(
                              tag: 'vet-drug-${item.id}',
                              child: Image.network(
                                item.primaryPhoto!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _placeholder();
                                },
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return _placeholder(
                                    child: CircularProgressIndicator(
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                                progress.expectedTotalBytes!
                                          : null,
                                      color: AppColors.accentBlue,
                                    ),
                                  );
                                },
                              ),
                            )
                          : _placeholder(),
                    ),
                    if (item.category != null && item.category!.isNotEmpty)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.category!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (hasStatus)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: _StatusPill(label: friendlyStatus),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priceText,
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (category.isNotEmpty) _MetaChip(label: category),
                      if (manufacturer.isNotEmpty)
                        _MetaChip(label: manufacturer),
                      if (unit.isNotEmpty) _MetaChip(label: unit),
                      if (item.stock != null)
                        _MetaChip(
                          label: '${context.tr('Stock')}: ${item.stock}',
                        ),
                    ],
                  ),
                  if (delivery.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_shipping,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            delivery,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder({Widget? child}) {
    return Container(
      color: AppColors.background,
      child: Center(
        child:
            child ?? const Icon(Icons.vaccines, color: Colors.grey, size: 36),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toUpperCase();
    final isAvailable =
        normalized.contains('AVAILABLE') || normalized.contains('IN STOCK');
    final color = isAvailable ? AppColors.primaryGreen : AppColors.accentRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
