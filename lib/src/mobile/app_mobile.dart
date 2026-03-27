import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_styles.dart';
import 'features/home/mobile_home_screen.dart';
import 'features/auth/mobile_login_screen.dart';
import 'features/wallet/mobile_wallet_screen.dart';
import 'features/wallet/mobile_add_card_screen.dart';
import 'features/reports/mobile_reports_screen.dart';
import 'features/calendar/mobile_calendar_screen.dart';
import 'features/profile/mobile_profile_screen.dart';

final _mobileRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const MobileLoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const MobileHomeScreen(),
    ),
    GoRoute(
      path: '/wallet',
      builder: (context, state) => const MobileWalletScreen(),
    ),
    GoRoute(
      path: '/add-card',
      builder: (context, state) => const MobileAddCardScreen(),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const MobileReportsScreen(),
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) => const MobileCalendarScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const MobileProfileScreen(),
    ),
  ],
);

class AppMobile extends ConsumerWidget {
  const AppMobile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'baothe.vn Mobile',
      debugShowCheckedModeBanner: false,
      routerConfig: _mobileRouter,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: Colors.white,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
    );
  }
}
