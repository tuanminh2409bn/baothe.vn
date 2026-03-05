import 'package:flutter/material.dart';
import '../constants/app_styles.dart';

enum AppButtonType { primary, secondary, outline }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isFullWidth;
  final AppButtonType type;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isFullWidth = true,
    this.type = AppButtonType.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Xác định màu sắc theo type
    final backgroundColor = type == AppButtonType.primary 
        ? AppColors.primary 
        : (type == AppButtonType.secondary ? AppColors.accentOrange : Colors.transparent);
    
    final textColor = type == AppButtonType.outline ? AppColors.primary : Colors.white;
    
    final border = type == AppButtonType.outline 
        ? Border.all(color: AppColors.border, width: 1.5) 
        : null;

    return Container(
      width: isFullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: border,
        boxShadow: type == AppButtonType.primary ? AppStyles.softShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: textColor, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: AppStyles.buttonText.copyWith(color: textColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
