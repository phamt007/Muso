import 'package:flutter/material.dart';

class AppColors {
  final Color background;
  final Color surface;
  final Color searchBar;
  final Color primaryAccent;
  final Color heartFavorite;
  final Color textPrimary;
  final Color textSecondary;

  // Constructor to build a palette set
  const AppColors({
    required this.background,
    required this.surface,
    required this.searchBar,
    required this.primaryAccent,
    required this.heartFavorite,
    required this.textPrimary,
    required this.textSecondary,
  });

  // ==========================================
  // COLOR PALETTE SETS HUB
  // ==========================================

  // Palette 1: Deep Purple (Your Current Theme)
  static const AppColors deepPurple = AppColors(
    background: Color(0xFF121212),
    surface: Color(0xFF1A1A1A),
    searchBar: Color(0xFF252525),
    primaryAccent: Colors.deepPurpleAccent,
    heartFavorite: Colors.redAccent,
    textPrimary: Colors.white,
    textSecondary: Color(0xFF9E9E9E),
  );

  // Palette 2: Cyber Blue / Neon Cyberpunk
  static const AppColors cyberBlue = AppColors(
    background: Color(0xFF121212),
    surface: Color(0xFF1A1A1A),
    searchBar: Color(0xFF252525),
    primaryAccent: Colors.cyanAccent,
    heartFavorite: Color(0xFFFF0055),
    textPrimary: Colors.white,
    textSecondary: Color(0xFF7085A3),
  );

  // Palette 3: Forest Mint
  static const AppColors forestMint = AppColors(
    background: Color(0xFF121212),
    surface: Color(0xFF1A1A1A),
    searchBar: Color(0xFF252525),
    primaryAccent: Colors.greenAccent,
    heartFavorite: Colors.amberAccent,
    textPrimary: Colors.white,
    textSecondary: Color(0xFF8AA393),
  );
}