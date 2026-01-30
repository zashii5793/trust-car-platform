import 'package:flutter/foundation.dart';

/// シンプルなサービスロケーター（依存性注入コンテナ）
///
/// get_it などの外部パッケージに依存せず、最小限のDIを実現
///
/// 使用例:
/// ```dart
/// // 登録
/// ServiceLocator.instance.register<VehicleRepository>(
///   () => FirebaseVehicleRepository(),
/// );
///
/// // 取得
/// final repo = ServiceLocator.instance.get<VehicleRepository>();
///
/// // テスト時のモック差し替え
/// ServiceLocator.instance.registerSingleton<VehicleRepository>(
///   MockVehicleRepository(),
/// );
/// ```
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  final Map<Type, _Factory> _factories = {};
  final Map<Type, Object> _singletons = {};

  /// ファクトリを登録（毎回新しいインスタンスを生成）
  void register<T extends Object>(T Function() factory) {
    _factories[T] = _Factory(factory, isSingleton: false);
  }

  /// シングルトンを登録（初回のみインスタンス生成）
  void registerLazySingleton<T extends Object>(T Function() factory) {
    _factories[T] = _Factory(factory, isSingleton: true);
  }

  /// シングルトンインスタンスを直接登録
  void registerSingleton<T extends Object>(T instance) {
    _singletons[T] = instance;
  }

  /// インスタンスを取得
  T get<T extends Object>() {
    // シングルトンとして既に存在する場合
    if (_singletons.containsKey(T)) {
      return _singletons[T] as T;
    }

    // ファクトリが登録されている場合
    final factory = _factories[T];
    if (factory == null) {
      throw ServiceLocatorException(
        'No factory registered for type $T. '
        'Make sure to register it before calling get<$T>().',
      );
    }

    final instance = factory.create() as T;

    // シングルトンの場合はキャッシュ
    if (factory.isSingleton) {
      _singletons[T] = instance;
    }

    return instance;
  }

  /// インスタンスを取得（未登録時はnullを返す）
  T? tryGet<T extends Object>() {
    try {
      return get<T>();
    } catch (_) {
      return null;
    }
  }

  /// 登録済みかどうか
  bool isRegistered<T extends Object>() {
    return _singletons.containsKey(T) || _factories.containsKey(T);
  }

  /// 登録を解除
  void unregister<T extends Object>() {
    _factories.remove(T);
    _singletons.remove(T);
  }

  /// 全ての登録を解除（テスト用）
  @visibleForTesting
  void reset() {
    _factories.clear();
    _singletons.clear();
  }

  /// 既存の登録を上書き（テスト用）
  @visibleForTesting
  void override<T extends Object>(T instance) {
    _factories.remove(T);
    _singletons[T] = instance;
  }
}

/// ファクトリ情報を保持するクラス
class _Factory {
  final Object Function() create;
  final bool isSingleton;

  _Factory(this.create, {required this.isSingleton});
}

/// サービスロケーター例外
class ServiceLocatorException implements Exception {
  final String message;

  ServiceLocatorException(this.message);

  @override
  String toString() => 'ServiceLocatorException: $message';
}

/// グローバルアクセス用のショートカット
ServiceLocator get sl => ServiceLocator.instance;
