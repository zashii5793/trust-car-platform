import 'package:flutter/material.dart';
import 'colors.dart';

/// アプリケーション全体で使用するタイポグラフィ定数
/// DESIGN_SYSTEM.md に準拠
/// フォント: Noto Sans JP (日本語), Inter (英数字)
class AppTextStyles {
  AppTextStyles._();

  // ========================================
  // Display Styles
  // ========================================

  /// Display Large: ページタイトル、重要な見出し
  /// Size: 32px / Line Height: 40px / Weight: 700
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    height: 1.25, // 40px / 32px
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Display Medium: セクション見出し
  /// Size: 24px / Line Height: 32px / Weight: 600
  static const TextStyle displayMedium = TextStyle(
    fontSize: 24,
    height: 1.33, // 32px / 24px
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // ========================================
  // Heading Styles
  // ========================================

  /// Heading Large: カード見出し、サブセクション
  /// Size: 20px / Line Height: 28px / Weight: 600
  static const TextStyle headingLarge = TextStyle(
    fontSize: 20,
    height: 1.4, // 28px / 20px
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Heading Medium: リスト項目見出し
  /// Size: 18px / Line Height: 26px / Weight: 600
  static const TextStyle headingMedium = TextStyle(
    fontSize: 18,
    height: 1.44, // 26px / 18px
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // ========================================
  // Body Styles
  // ========================================

  /// Body Large: 本文（メイン）
  /// Size: 16px / Line Height: 24px / Weight: 400
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 1.5, // 24px / 16px
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Body Medium: 本文（サブ）、説明文
  /// Size: 14px / Line Height: 20px / Weight: 400
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 1.43, // 20px / 14px
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Body Small: キャプション、補足情報
  /// Size: 12px / Line Height: 18px / Weight: 400
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    height: 1.5, // 18px / 12px
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  // ========================================
  // Label Styles
  // ========================================

  /// Label: ボタンラベル、フォームラベル
  /// Size: 14px / Line Height: 20px / Weight: 500
  static const TextStyle label = TextStyle(
    fontSize: 14,
    height: 1.43, // 20px / 14px
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Label Small: 小さいラベル
  /// Size: 12px / Line Height: 16px / Weight: 500
  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    height: 1.33, // 16px / 12px
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // ========================================
  // Button Text Styles
  // ========================================

  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    height: 1.43,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  // ========================================
  // Dark Mode Variants
  // ========================================

  static TextStyle get displayLargeDark =>
      displayLarge.copyWith(color: AppColors.darkTextPrimary);

  static TextStyle get displayMediumDark =>
      displayMedium.copyWith(color: AppColors.darkTextPrimary);

  static TextStyle get headingLargeDark =>
      headingLarge.copyWith(color: AppColors.darkTextPrimary);

  static TextStyle get headingMediumDark =>
      headingMedium.copyWith(color: AppColors.darkTextPrimary);

  static TextStyle get bodyLargeDark =>
      bodyLarge.copyWith(color: AppColors.darkTextPrimary);

  static TextStyle get bodyMediumDark =>
      bodyMedium.copyWith(color: AppColors.darkTextSecondary);

  static TextStyle get bodySmallDark =>
      bodySmall.copyWith(color: AppColors.darkTextTertiary);
}
