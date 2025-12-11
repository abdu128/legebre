import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../models/vet_drug.dart';

class VetDrugCard extends StatelessWidget {
  const VetDrugCard({super.key, required this.item, this.onTap});

  final VetDrug item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.compactCurrency(
      locale: 'en_ET',
      decimalDigits: 0,
      symbol: 'ETB ',
    );
    final priceText = item.price != null
        ? formatter.format(item.price)
        : 'Contact for price';

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
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priceText,
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatusPill(label: item.status ?? 'Available'),
                      const Spacer(),
                      if (item.unit != null && item.unit!.isNotEmpty)
                        Text(
                          item.unit!,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
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
            child ??
            const Icon(
              Icons.local_hospital_outlined,
              color: Colors.grey,
              size: 36,
            ),
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
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
