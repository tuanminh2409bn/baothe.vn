import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/mobile/app_mobile.dart';

void main() async {
  // Đảm bảo Flutter được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Bắt lỗi Framework (Lỗi Render, Widget...)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('❌ CRITICAL UI ERROR:');
    debugPrint(details.exceptionAsString());
    debugPrint('Stack trace:');
    debugPrint(details.stack?.toString());
  };

  // 2. Bắt lỗi Async (Lỗi logic chạy ngầm, API...)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('❌ CRITICAL ASYNC ERROR:');
    debugPrint('Cause: $error');
    debugPrint('Stack trace: $stack');
    return true; 
  };

  try {
    debugPrint('🚀 Đang khởi tạo MyFiny Mobile...');
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    runApp(
      const ProviderScope(
        child: AppMobile(),
      ),
    );
  } catch (e, stack) {
    debugPrint('❌ INITIALIZATION FAILED: $e');
    debugPrint(stack.toString());
  }
}
