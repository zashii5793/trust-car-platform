import 'package:flutter/foundation.dart';

/// アプリケーション設定
///
/// 環境変数、Feature Flags、設定値を一元管理
/// 将来的にはRemote Configと連携可能
class AppConfig {
  AppConfig._();

  static AppConfig? _instance;
  static AppConfig get instance => _instance ??= AppConfig._();

  // 環境
  AppEnvironment _environment = AppEnvironment.development;
  AppEnvironment get environment => _environment;

  // Feature Flags（デフォルト値）
  final Map<FeatureFlag, bool> _featureFlags = {
    FeatureFlag.darkMode: true,
    FeatureFlag.pushNotifications: true,
    FeatureFlag.aiRecommendations: true,
    FeatureFlag.pdfExport: true,
    FeatureFlag.imageUpload: true,
    FeatureFlag.googleSignIn: true,
    FeatureFlag.appleSignIn: true,
    FeatureFlag.offlineMode: false,
    FeatureFlag.analytics: true,
    FeatureFlag.crashReporting: true,
    FeatureFlag.maintenanceReminders: true,
    FeatureFlag.carInspectionReminders: true,
    FeatureFlag.costAnalysis: true,
    FeatureFlag.multiVehicle: true,
    FeatureFlag.socialSharing: false,
    FeatureFlag.premiumFeatures: false,
  };

  // 設定値
  final Map<String, dynamic> _settings = {};

  /// 初期化
  void init({
    required AppEnvironment environment,
    Map<FeatureFlag, bool>? featureFlags,
    Map<String, dynamic>? settings,
  }) {
    _environment = environment;

    if (featureFlags != null) {
      _featureFlags.addAll(featureFlags);
    }

    if (settings != null) {
      _settings.addAll(settings);
    }

    // 開発環境では全機能を有効化
    if (environment == AppEnvironment.development) {
      _enableAllFeaturesForDevelopment();
    }
  }

  void _enableAllFeaturesForDevelopment() {
    // デバッグビルドでのみ追加機能を有効化
    if (kDebugMode) {
      _featureFlags[FeatureFlag.offlineMode] = true;
      _featureFlags[FeatureFlag.socialSharing] = true;
    }
  }

  /// Feature Flagが有効かどうか
  bool isFeatureEnabled(FeatureFlag flag) {
    return _featureFlags[flag] ?? false;
  }

  /// Feature Flagを設定（Remote Config用）
  void setFeatureFlag(FeatureFlag flag, bool enabled) {
    _featureFlags[flag] = enabled;
  }

  /// 複数のFeature Flagを一括設定
  void setFeatureFlags(Map<FeatureFlag, bool> flags) {
    _featureFlags.addAll(flags);
  }

  /// 設定値を取得
  T? getSetting<T>(String key) {
    return _settings[key] as T?;
  }

  /// 設定値を取得（デフォルト値あり）
  T getSettingOrDefault<T>(String key, T defaultValue) {
    return (_settings[key] as T?) ?? defaultValue;
  }

  /// 設定値を設定
  void setSetting(String key, dynamic value) {
    _settings[key] = value;
  }

  /// 本番環境かどうか
  bool get isProduction => _environment == AppEnvironment.production;

  /// 開発環境かどうか
  bool get isDevelopment => _environment == AppEnvironment.development;

  /// ステージング環境かどうか
  bool get isStaging => _environment == AppEnvironment.staging;

  /// デバッグ情報を表示するかどうか
  bool get showDebugInfo => kDebugMode && !isProduction;

  /// API ベースURL
  String get apiBaseUrl => switch (_environment) {
    AppEnvironment.development => 'https://dev-api.trust-car.example.com',
    AppEnvironment.staging => 'https://staging-api.trust-car.example.com',
    AppEnvironment.production => 'https://api.trust-car.example.com',
  };

  /// Firebase プロジェクトID
  String get firebaseProjectId => switch (_environment) {
    AppEnvironment.development => 'trust-car-platform-dev',
    AppEnvironment.staging => 'trust-car-platform-staging',
    AppEnvironment.production => 'trust-car-platform',
  };

  /// 設定のスナップショットを取得（デバッグ用）
  Map<String, dynamic> toDebugMap() {
    return {
      'environment': _environment.name,
      'featureFlags': _featureFlags.map((k, v) => MapEntry(k.name, v)),
      'settings': _settings,
    };
  }

  /// リセット（テスト用）
  @visibleForTesting
  void reset() {
    _instance = null;
  }
}

/// アプリケーション環境
enum AppEnvironment {
  development,
  staging,
  production,
}

/// Feature Flags
enum FeatureFlag {
  // UI/UX
  darkMode,

  // 通知
  pushNotifications,
  maintenanceReminders,
  carInspectionReminders,

  // AI機能
  aiRecommendations,

  // データ出力
  pdfExport,
  socialSharing,

  // メディア
  imageUpload,

  // 認証
  googleSignIn,
  appleSignIn,

  // オフライン
  offlineMode,

  // 分析
  analytics,
  crashReporting,
  costAnalysis,

  // 機能制限
  multiVehicle,
  premiumFeatures,
}

/// AppConfig のショートカット
AppConfig get appConfig => AppConfig.instance;

/// Feature Flag チェックのショートカット
bool isFeatureEnabled(FeatureFlag flag) => appConfig.isFeatureEnabled(flag);
