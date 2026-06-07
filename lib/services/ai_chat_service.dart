import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/chat_message.dart';

/// Service for communicating with the Claude AI API.
///
/// Sends conversation history and vehicle context to generate
/// automotive advice responses.
class AiChatService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-haiku-4-5-20251001';
  static const _maxTokens = 1024;

  String get _apiKey => dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  /// Send a user message and receive an AI response.
  ///
  /// [userMessage] The current user input.
  /// [vehicleContext] Human-readable vehicle summary, e.g. "トヨタ プリウス 2020年式 走行距離45000km".
  /// [history] Previous messages in the conversation (loading messages are excluded).
  Future<Result<String, AppError>> ask({
    required String userMessage,
    required String vehicleContext,
    required List<ChatMessage> history,
  }) async {
    if (_apiKey.isEmpty) {
      return const Result.failure(
        ServerError('ANTHROPIC_API_KEYが設定されていません。.envファイルを確認してください。'),
      );
    }

    try {
      // Build message history for the API (exclude loading placeholder messages)
      final messages = [
        ...history
            .where((m) => !m.isLoading)
            .map((m) => {
                  'role': m.role == ChatRole.user ? 'user' : 'assistant',
                  'content': m.content,
                }),
        {'role': 'user', 'content': userMessage},
      ];

      final body = jsonEncode({
        'model': _model,
        'max_tokens': _maxTokens,
        'system': _buildSystemPrompt(vehicleContext),
        'messages': messages,
      });

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'x-api-key': _apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = (data['content'] as List).first as Map<String, dynamic>;
        return Result.success(content['text'] as String);
      } else {
        final error = jsonDecode(response.body);
        return Result.failure(
          ServerError(
            'AIの応答に失敗しました (${response.statusCode}): ${error['error']?['message'] ?? ''}',
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

  String _buildSystemPrompt(String vehicleContext) {
    return '''あなたはクルマの専門家AIアシスタントです。日本語で、親しみやすく丁寧に回答します。

ユーザーの車両情報:
$vehicleContext

できること:
- 消耗品（オイル・タイヤ・ワイパー・バッテリー等）の交換時期の目安
- 車のトラブルシューティングと対処法のアドバイス
- 整備工場への問い合わせ前の事前確認
- 車検・定期点検に関するアドバイス
- カスタム・ドレスアップのアドバイス
- 保険・税金に関する一般的な情報

回答スタイル:
- 簡潔に、箇条書きを活用する
- 専門用語には説明を添える
- 不確かな情報は「目安として」と前置きする
- 整備は専門家（整備士）に相談することを推奨する''';
  }
}
