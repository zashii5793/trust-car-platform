import 'package:flutter/widgets.dart';

/// 画面幅から判定されるデバイスサイズ種別（Material 3 window size class 準拠）。
enum DeviceSize { mobile, tablet, desktop }

/// レスポンシブレイアウトのブレークポイント定数と判定ヘルパー。
///
/// 判定ロジックは [sizeForWidth] などの純粋関数に集約し、
/// `BuildContext` に依存しないユニットテストを可能にしている。
class Breakpoints {
  Breakpoints._();

  // ========================================
  // Breakpoint Values (Material 3 window size classes)
  // ========================================

  /// タブレット（medium）判定の下限幅。これ以上 [desktop] 未満が tablet。
  static const double tablet = 600.0;

  /// デスクトップ（large）判定の下限幅。
  static const double desktop = 1200.0;

  /// 横並びナビ（NavigationRail）と多カラムレイアウトへ切り替える下限幅。
  ///
  /// Material 3 の expanded（840dp）以上で採用する。compact/medium
  /// （〜839dp）では従来のボトム `NavigationBar` を維持する。
  static const double wideLayout = 840.0;

  // ========================================
  // Pure Logic (testable without BuildContext)
  // ========================================

  /// 画面幅から [DeviceSize] を判定する純粋関数。
  static DeviceSize sizeForWidth(double width) {
    if (width >= desktop) return DeviceSize.desktop;
    if (width >= tablet) return DeviceSize.tablet;
    return DeviceSize.mobile;
  }

  /// 横並びナビ・多カラムへ切り替えるべき幅か（expanded 以上）。
  static bool useWideLayout(double width) => width >= wideLayout;

  /// `NavigationRail` を extended（ラベル併記）にすべき幅か（desktop 以上）。
  static bool useExtendedRail(double width) => width >= desktop;

  // ========================================
  // BuildContext Helpers
  // ========================================

  /// 現在のレイアウト幅から [DeviceSize] を判定する。
  static DeviceSize of(BuildContext context) =>
      sizeForWidth(MediaQuery.sizeOf(context).width);

  static bool isMobile(BuildContext context) =>
      of(context) == DeviceSize.mobile;

  static bool isTablet(BuildContext context) =>
      of(context) == DeviceSize.tablet;

  static bool isDesktop(BuildContext context) =>
      of(context) == DeviceSize.desktop;
}
