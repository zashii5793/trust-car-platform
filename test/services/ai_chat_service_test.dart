// AiChatService Unit Tests
//
// テスト対象: lib/services/ai_chat_service.dart
//
// カバー範囲:
//   1. 正常系: Cloud Function 200 レスポンス → Result.success
//   2. 429 レート制限 → Result.failure(ServerError)
//   3. 500 サーバーエラー → Result.failure(ServerError)
//   4. FIREBASE_FUNCTIONS_URL 未設定 → Result.failure(ServerError)
//   5. 未ログイン (currentUser == null) → Result.failure(ServerError)
//   6. ネットワークエラー (ClientException) → Result.failure(NetworkError)
//   7. タイムアウト (TimeoutException) → Result.failure(NetworkError)
//   8. history に isLoading=true が含まれる → 除外してリクエスト送信
//   9. Edge Cases: 空メッセージ / 空 history

import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/chat_message.dart';
import 'package:trust_car_platform/services/ai_chat_service.dart';

import 'ai_chat_service_test.mocks.dart';

// ---------------------------------------------------------------------------
// @GenerateMocks — build_runner で .mocks.dart を生成する
// ---------------------------------------------------------------------------
@GenerateMocks([http.Client, FirebaseAuth, User])
void main() {
  // Helper: 有効な dotenv を読み込む
  void loadValidEnv() {
    dotenv.testLoad(
      fileInput:
          'FIREBASE_FUNCTIONS_URL=https://asia-northeast1-test.cloudfunctions.net',
    );
  }

  // Helper: 空 dotenv を読み込む（URL 未設定）
  void loadEmptyEnv() {
    dotenv.testLoad(fileInput: '');
  }

  // Helper: ログイン済みのモックユーザーをセットアップ
  MockUser _makeAuthUser(MockFirebaseAuth mockAuth,
      {String idToken = 'test-id-token'}) {
    final mockUser = MockUser();
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.getIdToken(any)).thenAnswer((_) async => idToken);
    return mockUser;
  }

  // Helper: JSON レスポンスを作る
  http.Response _jsonResponse(Map<String, dynamic> body, int statusCode) {
    return http.Response(jsonEncode(body), statusCode);
  }

  // ---------------------------------------------------------------------------
  // ask() — 正常系
  // ---------------------------------------------------------------------------

  group('AiChatService.ask', () {
    group('正常系', () {
      test('200 レスポンスの場合 Result.success(reply) を返す', () async {
        loadValidEnv();
        final mockClient = MockClient();
        final mockAuth = MockFirebaseAuth();
        _makeAuthUser(mockAuth);

        when(mockClient.post(any,
                headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => _jsonResponse({'reply': 'テスト回答'}, 200));

        final service = AiChatService(httpClient: mockClient, auth: mockAuth);
        final result = await service.ask(
          userMessage: 'エンジンオイルの交換時期は？',
          vehicleContext: 'Toyota Prius 2020',
          history: [],
        );

        expect(result.isSuccess, true);
        expect(result.valueOrNull, 'テスト回答');
      });
    });

    // ---------------------------------------------------------------------------
    // 異常系: HTTP エラーコード
    // ---------------------------------------------------------------------------

    group('異常系: HTTP エラーコード', () {
      test('429 レスポンスの場合 ServerError を含む Result.failure を返す', () async {
        loadValidEnv();
        final mockClient = MockClient();
        final mockAuth = MockFirebaseAuth();
        _makeAuthUser(mockAuth);

        when(mockClient.post(any,
                headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => _jsonResponse(
                  {'error': '1日の利用上限に達しました。明日また試してください。'},
                  429,
                ));

        final service = AiChatService(httpClient: mockClient, auth: mockAuth);
        final result = await service.ask(
          userMessage: 'タイヤ交換は必要？',
          vehicleContext: 'Honda Fit 2018',
          history: [],
        );

        expect(result.isFailure, true);
        final error = result.errorOrNull;
        expect(error, isA<ServerError>());
        expect(error!.message, contains('1日の利用上限'));
      });

      test('500 レスポンスの場合 ServerError(statusCode=500) を含む Result.failure を返す',
          () async {
        loadValidEnv();
        final mockClient = MockClient();
        final mockAuth = MockFirebaseAuth();
        _makeAuthUser(mockAuth);

        when(mockClient.post(any,
                headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async =>
                _jsonResponse({'error': 'Internal Server Error'}, 500));

        final service = AiChatService(httpClient: mockClient, auth: mockAuth);
        final result = await service.ask(
          userMessage: '車検の費用は？',
          vehicleContext: 'Nissan Note 2019',
          history: [],
        );

        expect(result.isFailure, true);
        final error = result.errorOrNull;
        expect(error, isA<ServerError>());
        expect((error as ServerError).statusCode, 500);
        expect(error.message, contains('500'));
      });
    });

    // ---------------------------------------------------------------------------
    // 異常系: 設定・認証
    // ---------------------------------------------------------------------------

    group('異常系: 設定・認証', () {
      test('FIREBASE_FUNCTIONS_URL が空の場合 ServerError を返す', () async {
        loadEmptyEnv();
        final mockClient = MockClient();
        final mockAuth = MockFirebaseAuth();

        final service = AiChatService(httpClient: mockClient, auth: mockAuth);
        final result = await service.ask(
          userMessage: '燃費を良くするには？',
          vehicleContext: 'Suzuki Swift 2021',
          history: [],
        );

        expect(result.isFailure, true);
        final error = result.errorOrNull;
        expect(error, isA<ServerError>());
        expect(error!.message, contains('FIREBASE_FUNCTIONS_URL'));

        // HTTP リクエストは送信されない
        verifyNever(mockClient.post(any,
            headers: anyNamed('headers'), body: anyNamed('body')));
      });

      test('未ログイン (currentUser == null) の場合 ServerError を返す', () async {
        loadValidEnv();
        final mockClient = MockClient();
        final mockAuth = MockFirebaseAuth();
        when(mockAuth.currentUser).thenReturn(null);

        final service = AiChatService(httpClient: mockClient, auth: mockAuth);
        final result = await service.ask(
          userMessage: 'エアコンフィルターの交換は？',
          vehicleContext: 'Toyota Aqua 2022',
          history: [],
        );

        expect(result.isFailure, true);
        final error = result.errorOrNull;
        expect(error, isA<ServerError>());
        expect(error!.message, contains('ログインが必要'));

        // HTTP リクエストは送信されない
        verifyNever(mockClient.post(any,
            headers: anyNamed('headers'), body: anyNamed('body')));
      });
    });

    // ---------------------------------------------------------------------------
    // 異常系: ネットワーク・タイムアウト
    // ---------------------------------------------------------------------------

    group('異常系: ネットワーク・タイムアウト', () {
      test('ClientException が発生した場合 NetworkError を返す', () async {
        loadValidEnv();
        final mockClient = MockClient();
        final mockAuth = MockFirebaseAuth();
        _makeAuthUser(mockAuth);

        when(mockClient.post(any,
                headers: anyNamed('headers'), body: anyNamed('body')))
            .thenThrow(http.ClientException('Connection refused'));

        final service = AiChatService(httpClient: mockClient, auth: mockAuth);
        final result = await service.ask(
          userMessage: '駐車場のコツは？',
          vehicleContext: 'Mazda CX-5 2020',
          history: [],
        );

        expect(result.isFailure, true);
        final error = result.errorOrNull;
        expect(error, isA<NetworkError>());
        expect(error!.message, contains('ネットワークエラー'));
      });

      test('TimeoutException が発生した場合 NetworkError(タイムアウト) を返す', () async {
        loadValidEnv();
        final mockClient = MockClient();
        final mockAuth = MockFirebaseAuth();
        _makeAuthUser(mockAuth);

        when(mockClient.post(any,
                headers: anyNamed('headers'), body: anyNamed('body')))
            .thenThrow(TimeoutException(
                'Request timed out', const Duration(seconds: 60)));

        final service = AiChatService(httpClient: mockClient, auth: mockAuth);
        final result = await service.ask(
          userMessage: 'バッテリー交換の目安は？',
          vehicleContext: 'Subaru Forester 2019',
          history: [],
        );

        expect(result.isFailure, true);
        final error = result.errorOrNull;
        expect(error, isA<NetworkError>());
        expect(error!.message, contains('タイムアウト'));
      });
    });

    // ---------------------------------------------------------------------------
    // history のフィルタリング
    // ---------------------------------------------------------------------------

    group('history フィルタリング', () {
      test('isLoading=true のメッセージは除外されてリクエストが送られる', () async {
        loadValidEnv();
        final mockClient = MockClient();
        final mockAuth = MockFirebaseAuth();
        _makeAuthUser(mockAuth);

        when(mockClient.post(any,
                headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => _jsonResponse({'reply': 'OK'}, 200));

        final history = [
          ChatMessage(
            id: '1',
            role: ChatRole.user,
            content: 'タイヤの空気圧は？',
            createdAt: DateTime.now(),
          ),
          ChatMessage(
            id: '2',
            role: ChatRole.assistant,
            content: '通常は 230kPa です。',
            createdAt: DateTime.now(),
          ),
          // isLoading=true → 除外されるべき
          ChatMessage.loading(),
        ];

        final service = AiChatService(httpClient: mockClient, auth: mockAuth);
        await service.ask(
          userMessage: '他に注意点は？',
          vehicleContext: 'Honda N-BOX 2021',
          history: history,
        );

        // 送信された body を検証
        final captured = verify(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: captureAnyNamed('body'),
          ),
        ).captured;

        final sentBody =
            jsonDecode(captured.first as String) as Map<String, dynamic>;
        final sentHistory = sentBody['history'] as List<dynamic>;

        // isLoading=true のローディングメッセージが除外され、2件のみ送信される
        expect(sentHistory.length, 2);
        expect(
          sentHistory.every((m) => m['content'] != ''),
          true,
          reason: 'ローディング中の空コンテンツメッセージが除外されていない',
        );
      });
    });

    // ---------------------------------------------------------------------------
    // Edge Cases
    // ---------------------------------------------------------------------------

    group('Edge Cases', () {
      test('userMessage が空文字列でも正常にリクエストが送られる（サービス側は弾かない）', () async {
        loadValidEnv();
        final mockClient = MockClient();
        final mockAuth = MockFirebaseAuth();
        _makeAuthUser(mockAuth);

        when(mockClient.post(any,
                headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async =>
                _jsonResponse({'reply': 'Cloud Function 側が処理します'}, 200));

        final service = AiChatService(httpClient: mockClient, auth: mockAuth);
        final result = await service.ask(
          userMessage: '', // 空文字列
          vehicleContext: 'Toyota Yaris 2023',
          history: [],
        );

        // サービス側は空文字を弾かない → Result.success
        expect(result.isSuccess, true);

        // リクエストボディに userMessage: '' が含まれている
        final captured = verify(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: captureAnyNamed('body'),
          ),
        ).captured;
        final sentBody =
            jsonDecode(captured.first as String) as Map<String, dynamic>;
        expect(sentBody['userMessage'], '');
      });

      test('history が空リストの場合もリクエストが正常に送られる', () async {
        loadValidEnv();
        final mockClient = MockClient();
        final mockAuth = MockFirebaseAuth();
        _makeAuthUser(mockAuth);

        when(mockClient.post(any,
                headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer(
                (_) async => _jsonResponse({'reply': '初めてのご質問ですね'}, 200));

        final service = AiChatService(httpClient: mockClient, auth: mockAuth);
        final result = await service.ask(
          userMessage: '初めまして',
          vehicleContext: 'Daihatsu Tanto 2022',
          history: [], // 空リスト
        );

        expect(result.isSuccess, true);

        final captured = verify(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: captureAnyNamed('body'),
          ),
        ).captured;
        final sentBody =
            jsonDecode(captured.first as String) as Map<String, dynamic>;
        expect(sentBody['history'], isEmpty);
      });
    });
  });
}
