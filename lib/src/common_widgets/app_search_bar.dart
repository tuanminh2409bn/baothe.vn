import 'package:flutter/material.dart';
import '../constants/app_styles.dart';
import 'animated_hover.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final Function(String)? onSearch;
  final VoidCallback? onSearchPressed;

  const AppSearchBar({
    super.key,
    this.controller,
    this.onSearch,
    this.onSearchPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90, // Tăng chiều cao lên 90px theo chuẩn Gemini prompt
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24), // Bo góc hiện đại, ít tròn hơn một chút
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.textLight, size: 32),
          const SizedBox(width: 20),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onSearch,
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm thẻ, ngân hàng hoặc nhu cầu chi tiêu......',
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppColors.textLight, fontSize: 18),
              ),
              style: AppStyles.bodyMedium.copyWith(fontSize: 20),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedHover(
            scale: 1.05,
            child: GestureDetector(
              onTap: onSearchPressed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentOrange.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  'TÌM KIẾM NGAY',
                  style: AppStyles.buttonText.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
