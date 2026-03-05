import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/constants/app_styles.dart';
import 'src/features/cards/home_screen.dart';

import 'src/features/comparison/calculator_screen.dart';

void main() async {
  // Đảm bảo các dịch vụ của Flutter được khởi tạo trước khi gọi Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khởi tạo Firebase với cấu hình tự động từ flutterfire CLI
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    const ProviderScope(
      child: MyApp(),
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
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'baothe.vn',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: AppStyles.h2,
        ),
        textTheme: Theme.of(context).textTheme.apply(
              fontFamily: AppStyles.fontFamily,
              bodyColor: AppColors.textPrimary,
              displayColor: AppColors.textPrimary,
            ),
        useMaterial3: true,
      ),
    );
  }
}
