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
    final baseColor = AppColors.primaryGreen;
    final borderColor = selected
        ? baseColor
        : Colors.grey.withValues(alpha: .4);

    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: FilterChip(
        showCheckmark: false,
        selected: selected,
        onSelected: onSelected,
        side: BorderSide(color: borderColor),
        backgroundColor: Colors.white,
        selectedColor: baseColor.withValues(alpha: .12),
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        label: Text(
          label,
          style: TextStyle(
            color: selected ? baseColor : Colors.grey[900],
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
