import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_styles.dart';

class MobileFavoritesScreen extends StatelessWidget {
  const MobileFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary(context)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Thẻ yêu thích',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline_rounded, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Chưa có thẻ yêu thích nào',
              style: GoogleFonts.inter(fontSize: 16, color: AppColors.textLight(context)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                context.pop(); // Go back and user can navigate to explore cards
              },
              child: Text('Khám phá thẻ ngay', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary(context))),
            ),
          ],
        ),
      ),
    );
  }
}