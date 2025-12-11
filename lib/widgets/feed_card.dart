import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../models/feed_item.dart';

class FeedCard extends StatelessWidget {
  const FeedCard({super.key, required this.item, this.onTap});

  final FeedItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.compactCurrency(
      locale: 'en_ET',
      decimalDigits: 0,
      symbol: 'ETB ',
    );
    final priceLabel = item.price != null
        ? formatter.format(item.price)
        : 'Contact seller';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .07),
              blurRadius: 22,
              offset: const Offset(0, 12),
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
                              tag: 'feed-${item.id}',
                              child: Image.network(
                                item.primaryPhoto!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _placeholder(),
                              ),
                            )
                          : _placeholder(),
                    ),
                    if ((item.feedType ?? '').isNotEmpty)
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
                            item.feedType!,
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    priceLabel,
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if ((item.animalType ?? '').isNotEmpty)
                        _Chip(label: item.animalType!),
                      if ((item.brand ?? '').isNotEmpty)
                        _Chip(label: item.brand!),
                      if (item.weight != null)
                        _Chip(
                          label:
                              '${item.weight!.toStringAsFixed(item.weight! % 1 == 0 ? 0 : 1)} kg',
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

  Widget _placeholder() {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 40),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

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
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
