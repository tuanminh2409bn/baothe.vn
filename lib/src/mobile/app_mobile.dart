import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_styles.dart';
import 'features/home/mobile_home_screen.dart';
import 'features/auth/mobile_login_screen.dart';
import 'features/auth/mobile_register_screen.dart';
import 'features/wallet/mobile_wallet_screen.dart';
import 'features/wallet/mobile_add_card_screen.dart';
import 'features/reports/mobile_reports_screen.dart';
import 'features/calendar/mobile_calendar_screen.dart';
import 'features/profile/mobile_profile_screen.dart';
import 'features/transactions/mobile_add_transaction_screen.dart';
import 'features/wallet/mobile_card_detail_screen.dart';
import 'features/compare/mobile_compare_screen.dart';
import 'features/calculator/mobile_calculator_screen.dart';
import 'features/favorites/mobile_favorites_screen.dart';
import '../models/user_card_model.dart';

import 'mobile_main_layout.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellNavigatorWalletKey = GlobalKey<NavigatorState>(debugLabel: 'shellWallet');
final _shellNavigatorCalendarKey = GlobalKey<NavigatorState>(debugLabel: 'shellCalendar');
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(debugLabel: 'shellProfile');

final _mobileRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MobileLoginScreen(),
    ),
    GoRoute(
      path: '/register',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MobileRegisterScreen(),
    ),
    GoRoute(
      path: '/add-card',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MobileAddCardScreen(),
    ),
    GoRoute(
      path: '/add-transaction',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MobileAddTransactionScreen(),
    ),
    GoRoute(
      path: '/card-detail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final userCard = state.extra as UserCard;
        return MobileCardDetailScreen(userCard: userCard);
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MobileMainLayout(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _shellNavigatorHomeKey,
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const MobileHomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorWalletKey,
          routes: [
            GoRoute(
              path: '/wallet',
              builder: (context, state) => const MobileWalletScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorCalendarKey,
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const MobileCalendarScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorProfileKey,
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const MobileProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/reports',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MobileReportsScreen(),
    ),
    GoRoute(
      path: '/compare',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MobileCompareScreen(),
    ),
    GoRoute(
      path: '/calculator',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MobileCalculatorScreen(),
    ),
    GoRoute(
      path: '/favorites',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MobileFavoritesScreen(),
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
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            // Tắt bàn phím ảo khi chạm ra ngoài (cho iOS)
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
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
