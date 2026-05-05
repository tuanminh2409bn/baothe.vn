import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'src/constants/app_styles.dart';
import 'src/services/theme_service.dart';
import 'src/features/cards/home_screen.dart';
import 'src/features/cards/card_detail_screen.dart';
import 'src/features/comparison/calculator_screen.dart';
import 'src/features/comparison/comparison_screen.dart';
import 'src/features/auth/login_screen.dart';
import 'src/mobile/app_mobile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    const ProviderScope(
      child: kIsWeb ? MyApp() : AppMobile(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/calculator',
      builder: (context, state) => const CalculatorScreen(),
    ),
    GoRoute(
      path: '/card/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CardDetailScreen(cardId: id);
      },
    ),
    GoRoute(
      path: '/compare',
      builder: (context, state) => const ComparisonScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
  ],
);

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    
    return MaterialApp.router(
      title: 'MyFiny',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      themeMode: themeMode,
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
