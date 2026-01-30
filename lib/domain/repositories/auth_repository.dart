import '../../core/result/result.dart';
import '../../core/error/app_error.dart';
import '../../models/user.dart';

/// 認証リポジトリのインターフェース
abstract interface class AuthRepository {
  /// 現在のユーザーID
  String? get currentUserId;

  /// 認証状態の変更を監視
  Stream<AuthState> watchAuthState();

  /// メールとパスワードでサインイン
  Future<Result<AppUser, AppError>> signInWithEmail(String email, String password);

  /// メールとパスワードで新規登録
  Future<Result<AppUser, AppError>> signUpWithEmail(String email, String password);

  /// Googleでサインイン
  Future<Result<AppUser, AppError>> signInWithGoogle();

  /// Appleでサインイン
  Future<Result<AppUser, AppError>> signInWithApple();

  /// サインアウト
  Future<Result<void, AppError>> signOut();

  /// パスワードリセットメールを送信
  Future<Result<void, AppError>> sendPasswordResetEmail(String email);

  /// 現在のユーザー情報を取得
  Future<Result<AppUser, AppError>> getCurrentUser();

  /// ユーザー情報を更新
  Future<Result<void, AppError>> updateUser(AppUser user);

  /// アカウントを削除
  Future<Result<void, AppError>> deleteAccount();
}

/// 認証状態
sealed class AuthState {
  const AuthState();
}

/// 認証済み
final class Authenticated extends AuthState {
  final String userId;
  final String? email;
  final String? displayName;

  const Authenticated({
    required this.userId,
    this.email,
    this.displayName,
  });
}

/// 未認証
final class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// 認証状態確認中
final class AuthLoading extends AuthState {
  const AuthLoading();
}
