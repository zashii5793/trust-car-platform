/// アプリケーション全体で使用するエラー型
///
/// エラーの種類ごとに適切な処理やUIメッセージを提供できる
sealed class AppError implements Exception {
  /// エラーメッセージ（開発者向け）
  String get message;

  /// ユーザー向けメッセージ
  String get userMessage;

  /// リトライ可能かどうか
  bool get isRetryable;

  const AppError();

  // ファクトリコンストラクタ
  const factory AppError.network(String message, {String? userMessage}) = NetworkError;
  const factory AppError.auth(String message, {AuthErrorType type}) = AuthError;
  const factory AppError.validation(String message, {String? field}) = ValidationError;
  const factory AppError.notFound(String message, {String? resourceType}) = NotFoundError;
  const factory AppError.permission(String message) = PermissionError;
  const factory AppError.server(String message, {int? statusCode}) = ServerError;
  const factory AppError.cache(String message) = CacheError;
  const factory AppError.unknown(String message, {Object? originalError}) = UnknownError;
}

/// ネットワークエラー
final class NetworkError extends AppError {
  @override
  final String message;

  final String? _userMessage;

  const NetworkError(this.message, {String? userMessage}) : _userMessage = userMessage;

  @override
  String get userMessage => _userMessage ?? 'ネットワーク接続を確認してください';

  @override
  bool get isRetryable => true;

  @override
  String toString() => 'NetworkError: $message';
}

/// 認証エラー
final class AuthError extends AppError {
  @override
  final String message;

  final AuthErrorType type;

  const AuthError(this.message, {this.type = AuthErrorType.unknown});

  @override
  String get userMessage => switch (type) {
    AuthErrorType.invalidCredentials => 'メールアドレスまたはパスワードが正しくありません',
    AuthErrorType.userNotFound => 'ユーザーが見つかりません',
    AuthErrorType.emailAlreadyInUse => 'このメールアドレスは既に使用されています',
    AuthErrorType.weakPassword => 'パスワードが弱すぎます。より強力なパスワードを使用してください',
    AuthErrorType.sessionExpired => 'セッションが期限切れです。再度ログインしてください',
    AuthErrorType.tooManyRequests => 'リクエストが多すぎます。しばらく待ってからお試しください',
    AuthErrorType.unknown => '認証エラーが発生しました',
  };

  @override
  bool get isRetryable => type == AuthErrorType.tooManyRequests;

  @override
  String toString() => 'AuthError($type): $message';
}

/// 認証エラーの種類
enum AuthErrorType {
  invalidCredentials,
  userNotFound,
  emailAlreadyInUse,
  weakPassword,
  sessionExpired,
  tooManyRequests,
  unknown,
}

/// バリデーションエラー
final class ValidationError extends AppError {
  @override
  final String message;

  final String? field;

  const ValidationError(this.message, {this.field});

  @override
  String get userMessage => field != null ? '$fieldの入力内容を確認してください' : '入力内容を確認してください';

  @override
  bool get isRetryable => false;

  @override
  String toString() => 'ValidationError${field != null ? '($field)' : ''}: $message';
}

/// リソース未発見エラー
final class NotFoundError extends AppError {
  @override
  final String message;

  final String? resourceType;

  const NotFoundError(this.message, {this.resourceType});

  @override
  String get userMessage => resourceType != null ? '$resourceTypeが見つかりません' : 'データが見つかりません';

  @override
  bool get isRetryable => false;

  @override
  String toString() => 'NotFoundError${resourceType != null ? '($resourceType)' : ''}: $message';
}

/// 権限エラー
final class PermissionError extends AppError {
  @override
  final String message;

  const PermissionError(this.message);

  @override
  String get userMessage => 'この操作を行う権限がありません';

  @override
  bool get isRetryable => false;

  @override
  String toString() => 'PermissionError: $message';
}

/// サーバーエラー
final class ServerError extends AppError {
  @override
  final String message;

  final int? statusCode;

  const ServerError(this.message, {this.statusCode});

  @override
  String get userMessage => 'サーバーエラーが発生しました。しばらく待ってからお試しください';

  @override
  bool get isRetryable => true;

  @override
  String toString() => 'ServerError${statusCode != null ? '($statusCode)' : ''}: $message';
}

/// キャッシュエラー
final class CacheError extends AppError {
  @override
  final String message;

  const CacheError(this.message);

  @override
  String get userMessage => 'データの読み込みに失敗しました';

  @override
  bool get isRetryable => true;

  @override
  String toString() => 'CacheError: $message';
}

/// 不明なエラー
final class UnknownError extends AppError {
  @override
  final String message;

  final Object? originalError;

  const UnknownError(this.message, {this.originalError});

  @override
  String get userMessage => 'エラーが発生しました';

  @override
  bool get isRetryable => false;

  @override
  String toString() => 'UnknownError: $message${originalError != null ? ' (original: $originalError)' : ''}';
}

/// Firebaseエラーを AppError に変換するヘルパー
///
/// ログサービスが登録されている場合、自動的にエラーをログに記録する
AppError mapFirebaseError(dynamic error, {StackTrace? stackTrace}) {
  final appError = _mapFirebaseErrorInternal(error);

  // Automatic logging if LoggingService is available
  _logAppError(appError, stackTrace: stackTrace ?? StackTrace.current);

  return appError;
}

/// Internal error mapping logic
AppError _mapFirebaseErrorInternal(dynamic error) {
  final errorString = error.toString().toLowerCase();

  // Firebase Auth エラー
  if (errorString.contains('user-not-found')) {
    return const AppError.auth('User not found', type: AuthErrorType.userNotFound);
  }
  if (errorString.contains('wrong-password') || errorString.contains('invalid-credential')) {
    return const AppError.auth('Invalid credentials', type: AuthErrorType.invalidCredentials);
  }
  if (errorString.contains('email-already-in-use')) {
    return const AppError.auth('Email already in use', type: AuthErrorType.emailAlreadyInUse);
  }
  if (errorString.contains('weak-password')) {
    return const AppError.auth('Weak password', type: AuthErrorType.weakPassword);
  }
  if (errorString.contains('too-many-requests')) {
    return const AppError.auth('Too many requests', type: AuthErrorType.tooManyRequests);
  }

  // Firebase Firestore エラー
  if (errorString.contains('permission-denied')) {
    return AppError.permission(error.toString());
  }
  if (errorString.contains('not-found')) {
    return AppError.notFound(error.toString());
  }
  if (errorString.contains('unavailable')) {
    return AppError.network(error.toString());
  }

  // ネットワークエラー
  if (errorString.contains('network') || errorString.contains('connection')) {
    return AppError.network(error.toString());
  }

  return AppError.unknown(error.toString(), originalError: error);
}

/// Callback for logging AppErrors
///
/// This is set by injection.dart to enable automatic error logging
/// without creating circular dependencies.
typedef AppErrorLogger = void Function(AppError appError, {String? tag, StackTrace? stackTrace});
AppErrorLogger? _appErrorLogger;

/// Set the error logger callback (called from injection.dart)
void setAppErrorLogger(AppErrorLogger? logger) {
  _appErrorLogger = logger;
}

/// Log AppError using the registered logger if available
void _logAppError(AppError appError, {StackTrace? stackTrace}) {
  try {
    _appErrorLogger?.call(appError, tag: 'Firebase', stackTrace: stackTrace);
  } catch (_) {
    // Silently ignore if logging fails - don't break the error flow
  }
}
