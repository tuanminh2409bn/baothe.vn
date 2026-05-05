import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_styles.dart';

class AuthPlaceholder extends StatelessWidget {
  final String message;
  const AuthPlaceholder({
    super.key, 
    this.message = 'Vui lòng đăng nhập để sử dụng tính năng này'
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: AppColors.textLight(context),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppStyles.h3(context).copyWith(color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => context.push('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 140,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => context.push('/login'), // Giả định dùng chung màn login cho cả đăng ký
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary(context), width: 1.5),
                      foregroundColor: AppColors.primary(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Đăng ký', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
