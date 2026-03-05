import 'package:flutter/material.dart';
import '../constants/app_styles.dart';

class AnimatedHover extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;
  final bool showShadow;
  final bool useOrangeGlow;

  const AnimatedHover({
    super.key,
    required this.child,
    this.scale = 1.05,
    this.duration = const Duration(milliseconds: 200),
    this.showShadow = true, 
    this.useOrangeGlow = true, // Mặc định dùng hào quang cam khi hover
  });

  @override
  State<AnimatedHover> createState() => _AnimatedHoverState();
}

class _AnimatedHoverState extends State<AnimatedHover> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: widget.duration,
        curve: Curves.easeInOutCubic,
        transform: Matrix4.diagonal3Values(
          _isHovered ? widget.scale : 1.0,
          _isHovered ? widget.scale : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: (_isHovered && widget.showShadow)
              ? [
                  BoxShadow(
                    color: widget.useOrangeGlow 
                        ? AppColors.accentOrange.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: widget.child,
      ),
    );
  }
}
