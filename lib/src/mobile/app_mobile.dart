import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_styles.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import 'features/home/mobile_home_screen.dart';
import 'features/auth/mobile_login_screen.dart';
import 'features/auth/mobile_email_login_screen.dart';
import 'features/auth/mobile_register_screen.dart';
import 'features/wallet/mobile_wallet_screen.dart';
import 'features/wallet/mobile_add_card_screen.dart';
import 'features/wallet/mobile_add_wallet_screen.dart';
import 'features/reports/mobile_reports_screen.dart';
import 'features/calendar/mobile_calendar_screen.dart';
import 'features/profile/mobile_profile_screen.dart';
import 'features/transactions/mobile_add_transaction_screen.dart';
import '../models/transaction_model.dart';
import 'features/wallet/mobile_card_detail_screen.dart';
import 'features/compare/mobile_compare_screen.dart';
import 'features/calculator/mobile_calculator_screen.dart';
import 'features/favorites/mobile_favorites_screen.dart';
import 'features/ai_assistant/ai_chat_screen.dart';
import '../models/user_card_model.dart';

import 'mobile_main_layout.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellNavigatorWalletKey = GlobalKey<NavigatorState>(debugLabel: 'shellWallet');
final _shellNavigatorCalendarKey = GlobalKey<NavigatorState>(debugLabel: 'shellCalendar');
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(debugLabel: 'shellProfile');

// Class lắng nghe thay đổi để thông báo cho GoRouter refresh
class RouterListenable extends ChangeNotifier {
  RouterListenable(Ref ref) {
    _subscription = ref.listen(authStateProvider, (_, __) {
      notifyListeners();
    });
  }

  late final ProviderSubscription _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final routerListenableProvider = Provider((ref) => RouterListenable(ref));

// Provider cho GoRouter để có thể lắng nghe trạng thái auth
final mobileRouterProvider = Provider<GoRouter>((ref) {
  final listenable = ref.watch(routerListenableProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      // Đọc trạng thái auth bên trong redirect thay vì watch ở ngoài
      final authState = ref.read(authStateProvider);

      // Nếu đang loading thì không làm gì (đợi Firebase check auth)
      if (authState.isLoading) return null;

      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login' || 
                         state.matchedLocation == '/login-email' || 
                         state.matchedLocation == '/register';

      // Nếu chưa đăng nhập và không ở trang đăng nhập/đăng ký -> về login
      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      // Nếu đã đăng nhập mà cố vào trang login -> về trang chủ
      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MobileLoginScreen(),
      ),
      GoRoute(
        path: '/login-email',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MobileEmailLoginScreen(),
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
        path: '/add-wallet',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MobileAddWalletScreen(),
      ),
      GoRoute(
        path: '/add-transaction',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final typeStr = state.extra as String? ?? 'credit';
          final type = TransactionType.values.firstWhere(
            (e) => e.name == typeStr,
            orElse: () => TransactionType.credit,
          );
          return MobileAddTransactionScreen(type: type);
        },
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
      GoRoute(
        path: '/ai-chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AIChatScreen(),
      ),
    ],
  );
});

class AppMobile extends ConsumerWidget {
  const AppMobile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(mobileRouterProvider);

    return MaterialApp.router(
      title: 'MyFiny',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: ThemeMode.light, // Ép buộc luôn dùng giao diện sáng
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
        scaffoldBackgroundColor: AppColors.lBackground,
        primaryColor: AppColors.lPrimary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.lPrimary,
          brightness: Brightness.light,
          surface: AppColors.lSurface,
          onSurface: AppColors.lTextPrimary,
          primary: AppColors.lPrimary,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lSurface,
          foregroundColor: AppColors.lTextPrimary,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.dBackground,
        primaryColor: AppColors.dPrimary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.dPrimary,
          brightness: Brightness.dark,
          surface: AppColors.dSurface,
          onSurface: AppColors.dTextPrimary,
          primary: AppColors.dPrimary,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.dSurface,
          foregroundColor: AppColors.dTextPrimary,
          elevation: 0,
        ),
      ),
    );
  }
}

