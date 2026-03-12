import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Positioned.fill(child: CustomPaint(painter: _SplashPatternPainter())),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                Text(
                  'Legebere',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepBrown,
                  ),
                ),
                const SizedBox(height: 8),
                Text(context.tr('Trusted livestock marketplace')),
                const SizedBox(height: 32),
                const CircularProgressIndicator(color: AppColors.primaryGreen),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// class _SplashPatternPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = AppColors.primaryGreen.withValues(alpha: .06)
//       ..style = PaintingStyle.fill;

//     for (double i = 0; i < size.width; i += 80) {
//       for (double j = 0; j < size.height; j += 80) {
//         canvas.drawCircle(Offset(i, j), 24, paint);
//       }
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }
