/// Result型：成功/失敗を型安全に表現
///
/// 使用例:
/// ```dart
/// Future<Result<User, AppError>> getUser(String id) async {
///   try {
///     final user = await api.fetchUser(id);
///     return Result.success(user);
///   } catch (e) {
///     return Result.failure(AppError.network(e.toString()));
///   }
/// }
///
/// // 使用側
/// final result = await getUser('123');
/// result.when(
///   success: (user) => print(user.name),
///   failure: (error) => print(error.message),
/// );
/// ```
sealed class Result<T, E> {
  const Result._();

  /// 成功結果を作成
  const factory Result.success(T value) = Success<T, E>;

  /// 失敗結果を作成
  const factory Result.failure(E error) = Failure<T, E>;

  /// 成功かどうか
  bool get isSuccess => this is Success<T, E>;

  /// 失敗かどうか
  bool get isFailure => this is Failure<T, E>;

  /// 成功値を取得（失敗時はnull）
  T? get valueOrNull => switch (this) {
    Success(:final value) => value,
    Failure() => null,
  };

  /// エラーを取得（成功時はnull）
  E? get errorOrNull => switch (this) {
    Success() => null,
    Failure(:final error) => error,
  };

  /// パターンマッチング
  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  }) {
    return switch (this) {
      Success(:final value) => success(value),
      Failure(:final error) => failure(error),
    };
  }

  /// 成功値を変換
  Result<R, E> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success(:final value) => Result.success(transform(value)),
      Failure(:final error) => Result.failure(error),
    };
  }

  /// 成功値を変換（非同期）
  Future<Result<R, E>> mapAsync<R>(Future<R> Function(T value) transform) async {
    return switch (this) {
      Success(:final value) => Result.success(await transform(value)),
      Failure(:final error) => Result.failure(error),
    };
  }

  /// 成功値でResult を返す変換
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) transform) {
    return switch (this) {
      Success(:final value) => transform(value),
      Failure(:final error) => Result.failure(error),
    };
  }

  /// エラーを変換
  Result<T, R> mapError<R>(R Function(E error) transform) {
    return switch (this) {
      Success(:final value) => Result.success(value),
      Failure(:final error) => Result.failure(transform(error)),
    };
  }

  /// 成功値を取得（失敗時はデフォルト値）
  T getOrElse(T defaultValue) {
    return switch (this) {
      Success(:final value) => value,
      Failure() => defaultValue,
    };
  }

  /// 成功値を取得（失敗時は例外をスロー）
  T getOrThrow() {
    return switch (this) {
      Success(:final value) => value,
      Failure(:final error) => throw error as Object,
    };
  }
}

/// 成功結果
final class Success<T, E> extends Result<T, E> {
  final T value;

  const Success(this.value) : super._();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// 失敗結果
final class Failure<T, E> extends Result<T, E> {
  final E error;

  const Failure(this.error) : super._();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, E> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}

/// Result型のユーティリティ拡張
extension ResultExtensions<T, E> on Result<T, E> {
  /// 副作用を実行（成功時）
  Result<T, E> onSuccess(void Function(T value) action) {
    if (this case Success(:final value)) {
      action(value);
    }
    return this;
  }

  /// 副作用を実行（失敗時）
  Result<T, E> onFailure(void Function(E error) action) {
    if (this case Failure(:final error)) {
      action(error);
    }
    return this;
  }
}

/// `Future<Result>` の拡張
extension FutureResultExtensions<T, E> on Future<Result<T, E>> {
  /// 成功値を変換（非同期チェーン）
  Future<Result<R, E>> mapAsync<R>(R Function(T value) transform) async {
    final result = await this;
    return result.map(transform);
  }

  /// エラーを変換（非同期チェーン）
  Future<Result<T, R>> mapErrorAsync<R>(R Function(E error) transform) async {
    final result = await this;
    return result.mapError(transform);
  }
}
