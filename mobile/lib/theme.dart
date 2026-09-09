import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF1A1423);
  static const paper = Color(0xFFFFF8F0);
  static const card = Color(0xFFFFFFFF);
  static const accent = Color(0xFFC45C26);
  static const gold = Color(0xFFD4A017);
  static const moss = Color(0xFF2F6B5A);

  static Color level(String? code) {
    switch (code) {
      case 'SS':
        return const Color(0xFFC9A227);
      case 'S':
        return const Color(0xFFE85D04);
      case 'A':
        return const Color(0xFF6A4C93);
      case 'B':
        return const Color(0xFF4C6B8A);
      case 'C':
        return const Color(0xFF4A4A4A);
      default:
        return moss;
    }
  }

  static String levelEmoji(String? code) {
    switch (code) {
      case 'SS':
        return '🌟';
      case 'S':
        return '🔥';
      case 'A':
        return '⚡';
      case 'B':
        return '📦';
      case 'C':
        return '💀';
      default:
        return '🍀';
    }
  }

  static String tagLabel(String? tag) {
    switch (tag) {
      case 'DROPPED':
        return '掉签';
      case 'DORMANT':
        return '休眠';
      default:
        return '';
    }
  }

  static String todayStatus(String? status) {
    switch (status) {
      case 'COMPLETED':
        return '已完成';
      case 'EXPIRED':
        return '已过期';
      case 'VIEWED':
      case 'PENDING':
        return '未完成';
      default:
        return '未抽签';
    }
  }
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      surface: AppColors.paper,
    ),
    scaffoldBackgroundColor: AppColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.accent.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.accent : const Color(0xFF7A7068),
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7DDD2)),
      ),
    ),
  );
}
