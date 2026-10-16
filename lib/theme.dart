import 'package:flutter/material.dart';

class AppColors {
  final Color background;
  final Color surface;
  final Color primaryAccent;
  final Color searchBar;
  final Color textPrimary;
  final Color textSecondary;

  const AppColors({
    required this.background,
    required this.surface,
    required this.primaryAccent,
    required this.searchBar,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const deepPurple = AppColors(background: Color(0xFF121212), surface: Color(0xFF1E1E1E), primaryAccent: Colors.deepPurpleAccent, searchBar: Color(0xFF2C2C2C), textPrimary: Colors.white, textSecondary: Colors.grey);
  static const cyberBlue = AppColors(background: Color(0xFF0A0F24), surface: Color(0xFF111936), primaryAccent: Colors.cyanAccent, searchBar: Color(0xFF1A264F), textPrimary: Colors.white, textSecondary: Colors.grey);
  static const forestMint = AppColors(background: Color(0xFF0F1A15), surface: Color(0xFF16261E), primaryAccent: Colors.greenAccent, searchBar: Color(0xFF1F362A), textPrimary: Colors.white, textSecondary: Colors.grey);
}