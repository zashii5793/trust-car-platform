import 'package:flutter/material.dart';
import '../error/app_error.dart';
import '../result/result.dart';

/// 非同期データの状態を表現
///
/// UIでローディング、エラー、データの状態を統一的に扱う
sealed class AsyncValue<T> {
  const AsyncValue._();

  /// ローディング状態
  const factory AsyncValue.loading() = AsyncLoading<T>;

  /// データ取得成功
  const factory AsyncValue.data(T value) = AsyncData<T>;

  /// エラー状態
  const factory AsyncValue.error(AppError error) = AsyncError<T>;

  /// Resultからの変換
  factory AsyncValue.fromResult(Result<T, AppError> result) {
    return result.when(
      success: (value) => AsyncValue.data(value),
      failure: (error) => AsyncValue.error(error),
    );
  }

  /// ローディング中かどうか
  bool get isLoading => this is AsyncLoading<T>;

  /// データがあるかどうか
  bool get hasData => this is AsyncData<T>;

  /// エラーかどうか
  bool get hasError => this is AsyncError<T>;

  /// データを取得（なければnull）
  T? get valueOrNull {
    if (this case AsyncData(:final value)) {
      return value;
    }
    return null;
  }

  /// エラーを取得（なければnull）
  AppError? get errorOrNull {
    if (this case AsyncError(:final error)) {
      return error;
    }
    return null;
  }

  /// パターンマッチング
  R when<R>({
    required R Function() loading,
    required R Function(T value) data,
    required R Function(AppError err) error,
  }) {
    return switch (this) {
      AsyncLoading() => loading(),
      AsyncData(:final value) => data(value),
      AsyncError(error: final e) => error(e),
    };
  }

  /// パターンマッチング（オプショナル）
  R maybeWhen<R>({
    R Function()? loading,
    R Function(T value)? data,
    R Function(AppError err)? error,
    required R Function() orElse,
  }) {
    return switch (this) {
      AsyncLoading() => loading != null ? loading() : orElse(),
      AsyncData(:final value) => data != null ? data(value) : orElse(),
      AsyncError(error: final e) => error != null ? error(e) : orElse(),
    };
  }
}

/// ローディング状態
final class AsyncLoading<T> extends AsyncValue<T> {
  const AsyncLoading() : super._();
}

/// データ取得成功
final class AsyncData<T> extends AsyncValue<T> {
  final T value;

  const AsyncData(this.value) : super._();
}

/// エラー状態
final class AsyncError<T> extends AsyncValue<T> {
  final AppError error;

  const AsyncError(this.error) : super._();
}

/// AsyncValueを使ったWidget構築ヘルパー
class AsyncValueBuilder<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget Function()? loadingBuilder;
  final Widget Function(AppError error, VoidCallback? onRetry)? errorBuilder;
  final VoidCallback? onRetry;

  const AsyncValueBuilder({
    super.key,
    required this.value,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => loadingBuilder?.call() ?? _defaultLoading(),
      data: (data) => builder(data),
      error: (error) =>
          errorBuilder?.call(error, onRetry) ?? _defaultError(error, onRetry),
    );
  }

  Widget _defaultLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _defaultError(AppError error, VoidCallback? onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              error.userMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (error.isRetryable && onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// AsyncValueのリスト版Widget構築ヘルパー
class AsyncListBuilder<T> extends StatelessWidget {
  final AsyncValue<List<T>> value;
  final Widget Function(T item, int index) itemBuilder;
  final Widget Function()? loadingBuilder;
  final Widget Function(AppError error, VoidCallback? onRetry)? errorBuilder;
  final Widget Function()? emptyBuilder;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const AsyncListBuilder({
    super.key,
    required this.value,
    required this.itemBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.onRetry,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => loadingBuilder?.call() ?? _defaultLoading(),
      data: (items) {
        if (items.isEmpty) {
          return emptyBuilder?.call() ?? _defaultEmpty();
        }
        return ListView.builder(
          padding: padding,
          physics: physics,
          shrinkWrap: shrinkWrap,
          itemCount: items.length,
          itemBuilder: (context, index) => itemBuilder(items[index], index),
        );
      },
      error: (error) =>
          errorBuilder?.call(error, onRetry) ?? _defaultError(error, onRetry),
    );
  }

  Widget _defaultLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _defaultEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'データがありません',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _defaultError(AppError error, VoidCallback? onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              error.userMessage,
              textAlign: TextAlign.center,
            ),
            if (error.isRetryable && onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
