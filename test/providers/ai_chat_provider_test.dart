// AiChatProvider Unit Tests
//
// Tests conversation state management, history persistence, and error handling.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/chat_message.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/providers/ai_chat_provider.dart';
import 'package:trust_car_platform/services/ai_chat_service.dart';

// ---------------------------------------------------------------------------
// Stub AiChatService
// ---------------------------------------------------------------------------

class _StubAiChatService extends AiChatService {
  Result<String, AppError> response = const Result.success('AIの回答です');
  String? lastUserMessage;
  String? lastVehicleContext;
  List<ChatMessage>? lastHistory;
  int askCallCount = 0;

  _StubAiChatService();

  @override
  Future<Result<String, AppError>> ask({
    required String userMessage,
    required String vehicleContext,
    required List<ChatMessage> history,
  }) async {
    askCallCount++;
    lastUserMessage = userMessage;
    lastVehicleContext = vehicleContext;
    lastHistory = history;
    return response;
  }
}

Vehicle _makeVehicle({FuelType? fuelType}) => Vehicle(
      id: 'v1',
      userId: 'u1',
      maker: 'トヨタ',
      model: 'プリウス',
      year: 2022,
      grade: 'S',
      mileage: 30000,
      fuelType: fuelType,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

void main() {
  late _StubAiChatService service;
  late AiChatProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = _StubAiChatService();
    provider = AiChatProvider(service: service);
  });

  group('initial state', () {
    test('メッセージなし・ロード中でない・エラーなし', () {
      expect(provider.messages, isEmpty);
      expect(provider.isEmpty, isTrue);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    });
  });

  group('sendMessage', () {
    test('成功 → ユーザーメッセージとAI回答が追加される', () async {
      await provider.sendMessage('オイル交換の時期は？');

      expect(provider.messages.length, 2);
      expect(provider.messages[0].role, ChatRole.user);
      expect(provider.messages[0].content, 'オイル交換の時期は？');
      expect(provider.messages[1].role, ChatRole.assistant);
      expect(provider.messages[1].content, 'AIの回答です');
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    });

    test('失敗 → エラーがセットされ、ローディングメッセージは残らない', () async {
      service.response = const Result.failure(NetworkError('ネットワークエラー'));

      await provider.sendMessage('質問');

      expect(provider.messages.length, 1); // user message only
      expect(provider.messages[0].role, ChatRole.user);
      expect(provider.error, isNotNull);
      expect(provider.isLoading, isFalse);
      expect(provider.messages.any((m) => m.isLoading), isFalse);
    });

    test('車両あり → vehicleContext に車両情報が含まれる', () async {
      await provider.sendMessage('質問',
          vehicle: _makeVehicle(fuelType: FuelType.hybrid));

      expect(service.lastVehicleContext, contains('トヨタ プリウス'));
      expect(service.lastVehicleContext, contains('2022年式'));
      expect(service.lastVehicleContext, contains('30000km'));
      expect(service.lastVehicleContext, contains('ハイブリッド'));
    });

    test('車両なし → vehicleContext は「車両情報なし」', () async {
      await provider.sendMessage('質問');
      expect(service.lastVehicleContext, '車両情報なし');
    });

    test('前後の空白はトリムされる', () async {
      await provider.sendMessage('  質問です  ');
      expect(service.lastUserMessage, '質問です');
      expect(provider.messages[0].content, '質問です');
    });

    test('2回目の送信 → history に過去メッセージが渡される', () async {
      await provider.sendMessage('1回目');
      await provider.sendMessage('2回目');

      // History includes: user1, assistant1, user2 (loading excluded)
      expect(service.lastHistory!.length, 3);
      expect(service.lastHistory!.every((m) => !m.isLoading), isTrue);
    });

    group('Edge Cases', () {
      test('空文字 → 送信されない', () async {
        await provider.sendMessage('');
        expect(provider.messages, isEmpty);
        expect(service.askCallCount, 0);
      });

      test('空白のみ → 送信されない', () async {
        await provider.sendMessage('   ');
        expect(provider.messages, isEmpty);
        expect(service.askCallCount, 0);
      });

      test('エラー後に再送信 → エラーがクリアされる', () async {
        service.response = const Result.failure(NetworkError('エラー'));
        await provider.sendMessage('失敗する質問');
        expect(provider.error, isNotNull);

        service.response = const Result.success('回復しました');
        await provider.sendMessage('成功する質問');
        expect(provider.error, isNull);
      });
    });
  });

  group('clearHistory', () {
    test('全メッセージとエラーがクリアされる', () async {
      await provider.sendMessage('質問');
      expect(provider.messages, isNotEmpty);

      provider.clearHistory();

      expect(provider.messages, isEmpty);
      expect(provider.error, isNull);
      expect(provider.isEmpty, isTrue);
    });
  });

  group('loadHistory', () {
    test('保存済み履歴が復元される', () async {
      final saved = [
        ChatMessage(
          id: '1',
          role: ChatRole.user,
          content: '過去の質問',
          createdAt: DateTime(2024),
        ),
        ChatMessage(
          id: '2',
          role: ChatRole.assistant,
          content: '過去の回答',
          createdAt: DateTime(2024),
        ),
      ];
      SharedPreferences.setMockInitialValues({
        'ai_chat_history': jsonEncode(saved.map((m) => m.toJson()).toList()),
      });

      await provider.loadHistory();

      expect(provider.messages.length, 2);
      expect(provider.messages[0].content, '過去の質問');
      expect(provider.messages[1].content, '過去の回答');
    });

    test('保存データなし → 空のまま', () async {
      await provider.loadHistory();
      expect(provider.messages, isEmpty);
    });

    test('壊れたJSON → クラッシュせず空のまま', () async {
      SharedPreferences.setMockInitialValues({
        'ai_chat_history': '{invalid json!!',
      });

      await provider.loadHistory();
      expect(provider.messages, isEmpty);
    });
  });

  group('history persistence', () {
    test('送信後に履歴が SharedPreferences に保存される', () async {
      await provider.sendMessage('質問');
      // _saveHistory is fire-and-forget; allow it to complete
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ai_chat_history');
      expect(raw, isNotNull);
      final list = jsonDecode(raw!) as List<dynamic>;
      expect(list.length, 2); // user + assistant
    });

    test('21件以上 → 直近20件のみ永続化される', () async {
      // Send 11 messages → 22 entries (11 user + 11 assistant)
      for (var i = 0; i < 11; i++) {
        await provider.sendMessage('質問$i');
      }
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ai_chat_history');
      final list = jsonDecode(raw!) as List<dynamic>;
      expect(list.length, 20);
    });
  });
}
