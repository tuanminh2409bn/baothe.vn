import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // --- LIGHT MODE ---
  static const Color lBackground = Color(0xFFF8FAFC);
  static const Color lSurface = Color(0xFFFFFFFF);
  static const Color lPrimary = Color(0xFF1E3A8A); // Navy Blue
  static const Color lAccent = Color(0xFF3B82F6);  // Blue
  static const Color lTextPrimary = Color(0xFF0F172A);
  static const Color lTextSecondary = Color(0xFF64748B);
  static const Color lTextLight = Color(0xFF94A3B8);
  static const Color lBorder = Color(0xFFE2E8F0);

  // --- DARK MODE ---
  static const Color dBackground = Color(0xFF0F172A);
  static const Color dSurface = Color(0xFF1E293B);
  static const Color dPrimary = Color(0xFF3B82F6);
  static const Color dAccent = Color(0xFF60A5FA);
  static const Color dTextPrimary = Color(0xFFF8FAFC);
  static const Color dTextSecondary = Color(0xFF94A3B8);
  static const Color dTextLight = Color(0xFF64748B);
  static const Color dBorder = Color(0xFF334155);

  // Trạng thái chung
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Helper methods để lấy màu theo theme
  static Color background(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? dBackground : lBackground;
  
  static Color surface(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? dSurface : lSurface;
      
  static Color primary(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? dPrimary : lPrimary;

  static Color accent(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? dAccent : lAccent;
      
  static Color textPrimary(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? dTextPrimary : lTextPrimary;
      
  static Color textSecondary(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? dTextSecondary : lTextSecondary;

  static Color textLight(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? dTextLight : lTextLight;
      
  static Color border(BuildContext context) => 
      Theme.of(context).brightness == Brightness.dark ? dBorder : lBorder;

  // Aliases for backward compatibility during refactoring
  static const Color accentOrange = warning;
}

class AppStyles {
  static const String fontFamily = 'Inter';

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> primaryGlow(BuildContext context) => [
    BoxShadow(
      color: AppColors.primary(context).withValues(alpha: 0.2),
      blurRadius: 25,
      spreadRadius: 2,
    ),
  ];

  static TextStyle h1(BuildContext context) => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary(context),
      );

  static TextStyle h2(BuildContext context) => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(context),
      );

  static TextStyle h3(BuildContext context) => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(context),
      );

  static TextStyle h4(BuildContext context) => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary(context),
      );

  static TextStyle bodyMedium(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        color: AppColors.textPrimary(context),
      );

  static TextStyle labelSmall(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textSecondary(context),
      );
      
  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 16,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      );
}
