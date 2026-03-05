import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Nền tảng chính
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  
  // Màu thương hiệu/Chính
  static const Color primary = Color(0xFF1E293B); // Navy đậm chuyên nghiệp
  static const Color accent = Color(0xFFB4936A);  // Màu vàng đồng (Bronze)
  static const Color accentOrange = Color(0xFFF97316); // Cam nổi bật
  
  // Màu chữ
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  
  // Trạng thái
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  
  // Đường kẻ & Bóng
  static const Color border = Color(0xFFE2E8F0);
}

class AppStyles {
  static const String fontFamily = 'Roboto';

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];

  static List<BoxShadow> get orangeGlow => [
    BoxShadow(
      color: AppColors.accentOrange.withValues(alpha: 0.2),
      blurRadius: 20,
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
