import 'package:flutter/material.dart';

/// アプリケーション全体で使用するスペーシング定数
/// DESIGN_SYSTEM.md に準拠
/// 基本単位: 4px
class AppSpacing {
  AppSpacing._();

  // ========================================
  // Spacing Values
  // ========================================

  /// XXS: 4px - 最小の余白
  static const double xxs = 4.0;

  /// XS: 8px - タイトな余白
  static const double xs = 8.0;

  /// S: 12px - 小さい余白
  static const double sm = 12.0;

  /// M: 16px - 標準的な余白 (デフォルト)
  static const double md = 16.0;

  /// L: 24px - ゆとりのある余白
  static const double lg = 24.0;

  /// XL: 32px - セクション間の余白
  static const double xl = 32.0;

  /// XXL: 48px - 大きなセクション間
  static const double xxl = 48.0;

  // ========================================
  // Border Radius
  // ========================================

  /// 小さい角丸: 4px
  static const double radiusXs = 4.0;

  /// 標準の角丸: 8px
  static const double radiusSm = 8.0;

  /// 中程度の角丸: 12px
  static const double radiusMd = 12.0;

  /// 大きい角丸: 16px
  static const double radiusLg = 16.0;

  /// 完全な円形: 100px
  static const double radiusFull = 100.0;

  // ========================================
  // Common BorderRadius Objects
  // ========================================

  static const BorderRadius borderRadiusXs =
      BorderRadius.all(Radius.circular(radiusXs));

  static const BorderRadius borderRadiusSm =
      BorderRadius.all(Radius.circular(radiusSm));

  static const BorderRadius borderRadiusMd =
      BorderRadius.all(Radius.circular(radiusMd));

  static const BorderRadius borderRadiusLg =
      BorderRadius.all(Radius.circular(radiusLg));

  // ========================================
  // Common EdgeInsets
  // ========================================

  /// カード内部のパディング: 16px
  static const EdgeInsets paddingCard = EdgeInsets.all(md);

  /// ボタン内部のパディング: horizontal 24px, vertical 12px
  static const EdgeInsets paddingButton = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: sm,
  );

  /// フォームフィールドのパディング: horizontal 16px, vertical 12px
  static const EdgeInsets paddingTextField = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  /// 画面全体のパディング: 16px
  static const EdgeInsets paddingScreen = EdgeInsets.all(md);

  /// リスト項目間のマージン: 16px (bottom)
  static const EdgeInsets marginListItem = EdgeInsets.only(bottom: md);

  /// セクション間のマージン: 24px (bottom)
  static const EdgeInsets marginSection = EdgeInsets.only(bottom: lg);

  // ========================================
  // Common SizedBox Widgets
  // ========================================

  /// 水平方向のXS間隔 (8px)
  static const SizedBox horizontalXs = SizedBox(width: xs);

  /// 水平方向のS間隔 (12px)
  static const SizedBox horizontalSm = SizedBox(width: sm);

  /// 水平方向のM間隔 (16px)
  static const SizedBox horizontalMd = SizedBox(width: md);

  /// 水平方向のL間隔 (24px)
  static const SizedBox horizontalLg = SizedBox(width: lg);

  /// 垂直方向のXXS間隔 (4px)
  static const SizedBox verticalXxs = SizedBox(height: xxs);

  /// 垂直方向のXS間隔 (8px)
  static const SizedBox verticalXs = SizedBox(height: xs);

  /// 垂直方向のS間隔 (12px)
  static const SizedBox verticalSm = SizedBox(height: sm);

  /// 垂直方向のM間隔 (16px)
  static const SizedBox verticalMd = SizedBox(height: md);

  /// 垂直方向のL間隔 (24px)
  static const SizedBox verticalLg = SizedBox(height: lg);

  /// 垂直方向のXL間隔 (32px)
  static const SizedBox verticalXl = SizedBox(height: xl);

  /// 垂直方向のXXL間隔 (48px)
  static const SizedBox verticalXxl = SizedBox(height: xxl);

  // ========================================
  // Icon Sizes
  // ========================================

  /// 小さいアイコン: 16px
  static const double iconSm = 16.0;

  /// 標準アイコン: 24px
  static const double iconMd = 24.0;

  /// 大きいアイコン: 32px
  static const double iconLg = 32.0;

  /// 特大アイコン: 48px
  static const double iconXl = 48.0;

  /// 空状態アイコン: 80px
  static const double iconEmpty = 80.0;

  // ========================================
  // Tap Target Sizes (Accessibility)
  // ========================================

  /// 最小タップターゲット: 48px
  static const double tapTargetMin = 48.0;

  /// 推奨タップターゲット: 56px
  static const double tapTargetRecommended = 56.0;

  // ========================================
  // App Bar Height
  // ========================================

  static const double appBarHeight = 64.0;

  // ========================================
  // Bottom Navigation Height
  // ========================================

  static const double bottomNavHeight = 56.0;
}
