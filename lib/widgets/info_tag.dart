import 'package:flutter/material.dart';

import '../app_theme.dart';

class InfoTag extends StatelessWidget {
  const InfoTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, color: AppColors.deepBrown),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

