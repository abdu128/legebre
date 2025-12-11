import 'package:flutter/material.dart';

import '../app_theme.dart';

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
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Icon(
                    Icons.grass_rounded,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Legebere',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepBrown,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Trusted livestock marketplace'),
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
