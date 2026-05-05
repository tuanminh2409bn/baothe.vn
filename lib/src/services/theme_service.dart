import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Đơn giản hóa themeProvider để luôn trả về Light Mode theo yêu cầu
final themeProvider = Provider<ThemeMode>((ref) {
  return ThemeMode.light;
});

// Giữ lại class này để tránh lỗi compile nếu có chỗ đang gọi, 
// nhưng không thực hiện logic chuyển đổi nữa.
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void toggleTheme() {}
  Future<void> setThemeMode(ThemeMode mode) async {}
}
