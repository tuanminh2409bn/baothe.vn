import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class FinyAIFloatingButton extends StatelessWidget {
  const FinyAIFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: GestureDetector(
        onTap: () {
          context.push('/ai-chat');
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF8B5CF6), // Premium purple
                Color(0xFF3B82F6), // Premium blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.auto_awesome, // Sparkle icon
              color: Colors.white,
              size: 28,
            ),
          ),
        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
         .scaleXY(begin: 1.0, end: 1.05, duration: 1500.ms, curve: Curves.easeInOutSine)
         .shimmer(duration: 2500.ms, color: Colors.white.withValues(alpha: 0.5)),
      ),
    );
  }
}
