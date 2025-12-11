import 'package:flutter/material.dart';

import '../app_theme.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primaryGreen),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

