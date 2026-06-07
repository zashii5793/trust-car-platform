import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/chat_message.dart';

/// Service for communicating with the AI chat Cloud Function.
///
/// The Cloud Function (`askCarAi`) holds the ANTHROPIC_API_KEY as a Firebase
/// secret — it is never embedded in the mobile binary.
/// Every request is authenticated via a Firebase ID token.
class AiChatService {
  // Cloud Function base URL — set FIREBASE_FUNCTIONS_URL in .env
  // e.g. https://asia-northeast1-trust-car-platform.cloudfunctions.net
  String get _functionsBaseUrl =>
      dotenv.env['FIREBASE_FUNCTIONS_URL'] ?? '';

  String get _endpoint => '$_functionsBaseUrl/askCarAi';

  /// Send a user message and receive an AI response via the Cloud Function.
  ///
  /// [userMessage] The current user input.
  /// [vehicleContext] Human-readable vehicle summary.
  /// [history] Previous messages in the conversation (loading messages excluded).
  Future<Result<String, AppError>> ask({
    required String userMessage,
    required String vehicleContext,
    required List<ChatMessage> history,
  }) async {
    if (_functionsBaseUrl.isEmpty) {
      return const Result.failure(
        ServerError('FIREBASE_FUNCTIONS_URLが設定されていません。.envファイルを確認してください。'),
      );
    }

    // Obtain a fresh Firebase ID token to authenticate with the Cloud Function.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Result.failure(
        ServerError('ログインが必要です。'),
      );
    }

    final String? idToken;
    try {
      idToken = await user.getIdToken();
    } catch (e) {
      return Result.failure(ServerError('認証トークンの取得に失敗しました: $e'));
    }

    if (idToken == null) {
      return const Result.failure(ServerError('認証トークンの取得に失敗しました。'));
    }

    try {
      final messages = history
          .where((m) => !m.isLoading)
          .map((m) => {
                'role': m.role == ChatRole.user ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      final body = jsonEncode({
        'userMessage': userMessage,
        'vehicleContext': vehicleContext,
        'history': messages,
      });

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Result.success(data['reply'] as String);
      } else if (response.statusCode == 429) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Result.failure(
          ServerError(data['error'] as String? ?? '1日の利用上限に達しました。'),
        );
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Result.failure(
          ServerError(
            'AIの応答に失敗しました (${response.statusCode}): ${data['error'] ?? ''}',
            statusCode: response.statusCode,
          ),
        );
      }
    } on http.ClientException catch (e) {
      return Result.failure(NetworkError('ネットワークエラー: ${e.message}'));
    } on TimeoutException {
      return const Result.failure(
        NetworkError('AIの応答がタイムアウトしました。再度お試しください。'),
      );
    } catch (e) {
      return Result.failure(ServerError('AIとの通信に失敗しました: $e'));
    }
  }
}
