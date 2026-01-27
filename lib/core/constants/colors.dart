import 'package:flutter/material.dart';

/// アプリケーション全体で使用するカラー定数
/// DESIGN_SYSTEM.md に準拠
class AppColors {
  AppColors._();

  // ========================================
  // Primary Colors (Deep Blue)
  // ========================================
  static const Color primary = Color(0xFF1A4D8F);
  static const Color primaryHover = Color(0xFF2563B8);
  static const Color primaryActive = Color(0xFF0D3A6F);

  // ========================================
  // Secondary Colors (Trust Green)
  // ========================================
  static const Color secondary = Color(0xFF2D7A5F);
  static const Color secondaryHover = Color(0xFF43A881);
  static const Color secondaryActive = Color(0xFF1F5A45);

  // ========================================
  // Semantic Colors
  // ========================================
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ========================================
  // Neutral Colors (Light Mode)
  // ========================================
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textTertiary = Color(0xFF6B7280);
  static const Color border = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFF9CA3AF);
  static const Color backgroundSecondary = Color(0xFFD1D5DB);
  static const Color backgroundLight = Color(0xFFF3F4F6);
  static const Color backgroundWhite = Color(0xFFFFFFFF);

  // ========================================
  // Dark Mode Colors
  // ========================================
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2C2C2C);
  static const Color darkPrimary = Color(0xFF4A90E2);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB3B3B3);
  static const Color darkTextTertiary = Color(0xFF808080);

  // ========================================
  // Accent Colors (SNS/Custom)
  // ========================================
  static const Color accentCustom = Color(0xFF8B5CF6);
  static const Color accentCommunity = Color(0xFFEC4899);
  static const Color accentDrive = Color(0xFFF97316);

  // ========================================
  // Maintenance Type Colors
  // ========================================
  static const Color maintenanceRepair = Color(0xFFEF4444);
  static const Color maintenanceInspection = Color(0xFF3B82F6);
  static const Color maintenanceParts = Color(0xFFF97316);
  static const Color maintenanceCarInspection = Color(0xFF10B981);

  // ========================================
  // Error State Background Colors
  // ========================================
  static const Color errorBackground = Color(0xFFFEE2E2);
  static const Color successBackground = Color(0xFFD1FAE5);
  static const Color warningBackground = Color(0xFFFEF3C7);
  static const Color infoBackground = Color(0xFFDBEAFE);
}
