import 'package:flutter/material.dart';

import '../app_theme.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: FilterChip(
        showCheckmark: false,
        selected: selected,
        onSelected: onSelected,
        side: BorderSide(
          color: selected
              ? AppColors.primaryGreen
              : Colors.grey.shade300,
          width: selected ? 1.5 : 1,
        ),
        backgroundColor: Colors.white,
        selectedColor: AppColors.primaryGreen.withValues(alpha: .1),
        elevation: selected ? 1 : 0,
        pressElevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        labelPadding: EdgeInsets.zero,
        label: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primaryGreen : Colors.grey.shade700,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
