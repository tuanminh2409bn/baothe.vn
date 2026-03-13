import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Nền tảng chính - Elegant Brown & Cream
  static const Color background = Color(0xFFFDFBF7); // Màu kem nhẹ
  static const Color surface = Color(0xFFFFFFFF);
  
  // Tông màu chủ đạo - Nâu Coffee & Gold/Bronze
  static const Color primary = Color(0xFF4A3728);   // Nâu đậm Coffee
  static const Color accent = Color(0xFFB4936A);    // Màu vàng đồng (Bronze/Gold)
  static const Color accentGold = Color(0xFFD4AF37); // Vàng sáng Gold
  static const Color accentOrange = Color(0xFFCA8A04); // Vàng đậm Gold
  
  // Màu chữ - Tông ấm
  static const Color textPrimary = Color(0xFF2D241E); // Nâu đen coffee
  static const Color textSecondary = Color(0xFF7D6E64); // Nâu xám ấm
  static const Color textLight = Color(0xFFA6998F);
  
  // Trạng thái
  static const Color success = Color(0xFF849271); // Xanh rêu (hợp tông nâu)
  static const Color error = Color(0xFF9E4545);   // Đỏ nâu
  static const Color warning = Color(0xFFB48346);
  
  // Đường kẻ & Bóng - Tông ấm
  static const Color border = Color(0xFFE8E2D9);
}

class AppStyles {
  static const String fontFamily = 'Roboto';

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF4A3728).withValues(alpha: 0.05),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get goldGlow => [
    BoxShadow(
      color: AppColors.accentGold.withValues(alpha: 0.2),
      blurRadius: 25,
      spreadRadius: 2,
    ),
  ];

  static TextStyle get h1 => GoogleFonts.roboto(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get h2 => GoogleFonts.roboto(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.roboto(
        fontSize: 16,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelSmall => GoogleFonts.roboto(
        fontSize: 14,
        color: AppColors.textSecondary,
      );
      
  static TextStyle get buttonText => GoogleFonts.roboto(
        fontSize: 16,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      );
}
