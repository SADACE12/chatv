import 'package:flutter/material.dart';

class AppColors {
  // Уведомляет приложение о смене темы (true = тёмная, false = светлая)
  static final ValueNotifier<bool> isDarkNotifier = ValueNotifier(true);
  static bool get isDark => isDarkNotifier.value;
  static void toggleTheme() => isDarkNotifier.value = !isDarkNotifier.value;

  // Динамические цвета
  static Color get bg => isDark ? Colors.black : const Color(0xFFF0F2F5);
  static Color get card => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  static Color get text => isDark ? Colors.white : const Color(0xFF1A1A1A);
  static Color get textSub => isDark ? Colors.grey : Colors.black54;
  static Color get border => isDark ? Colors.white10 : Colors.black12;
  static Color get sidebar => isDark ? const Color(0xFF121212) : Colors.white;
  static Color get input => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE4E6EB);
  
  // Цвета для кнопок, чтобы они контрастировали
  static Color get buttonBg => isDark ? Colors.white : Colors.black;
  static Color get buttonText => isDark ? Colors.black : Colors.white;
}