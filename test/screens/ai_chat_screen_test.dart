// AiChatScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows 'AIに聞く' title
//     2. Shows clear-history icon button
//   Empty state:
//     3. Shows empty-state headline when no messages
//     4. Shows input hint text
//     5. Shows suggestion chips
//   Message flow:
//     6. Entering text and tapping send shows user message bubble
//     7. AI reply appears after send
//   Clear flow:
//     8. Tapping clear returns to empty state

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/chat_message.dart';
import 'package:trust_car_platform/providers/vehicle_provider.dart';
import 'package:trust_car_platform/screens/ai_chat/ai_chat_screen.dart';
import 'package:trust_car_platform/services/ai_chat_service.dart';
import 'package:trust_car_platform/services/firebase_service.dart';

// ---------------------------------------------------------------------------
// Mocks / Stubs
// ---------------------------------------------------------------------------

class _MockAiChatService implements AiChatService {
  String replyText;
  AppError? error;
  int callCount = 0;

  _MockAiChatService({this.replyText = 'AIからの返答です', this.error});

  @override
  Future<Result<String, AppError>> ask({
    required String userMessage,
    required String vehicleContext,
    required List<ChatMessage> history,
  }) async {
    callCount++;
    if (error != null) return Result.failure(error!);
    return Result.success(replyText);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubFirebaseService implements FirebaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildScreen(_MockAiChatService mock) {
  sl.override<AiChatService>(mock);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<VehicleProvider>(
        create: (_) => VehicleProvider(firebaseService: _StubFirebaseService()),
      ),
    ],
    child: const MaterialApp(home: AiChatScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() {
    Injection.reset();
  });

  // =========================================================================
  group('AiChatScreen — AppBar', () {
    testWidgets('1. タイトル「AIに聞く」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockAiChatService()));
      await tester.pump();
      await tester.pump();

      expect(find.text('AIに聞く'), findsOneWidget);
    });

    testWidgets('2. 会話クリアアイコンボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockAiChatService()));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });

  // =========================================================================
  group('AiChatScreen — Empty state', () {
    testWidgets('3. 初期状態では空状態のヘッドラインが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockAiChatService()));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('クルマの専門家AIに'), findsOneWidget);
    });

    testWidgets('4. 入力フィールドのヒントテキストが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockAiChatService()));
      await tester.pump();
      await tester.pump();

      expect(find.text('車のことを何でも聞いてください'), findsOneWidget);
    });

    testWidgets('5. サジェストチップが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockAiChatService()));
      await tester.pump();
      await tester.pump();

      // Default chips for no-vehicle state
      expect(find.textContaining('オイル交換'), findsOneWidget);
    });
  });

  // =========================================================================
  group('AiChatScreen — Message flow', () {
    testWidgets('6. メッセージ送信でユーザーバブルが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockAiChatService()));
      await tester.pump();
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextField, '車のことを何でも聞いてください'), 'タイヤの空気圧は？');
      // Tap the send button (IconButton with Icons.send)
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(find.text('タイヤの空気圧は？'), findsOneWidget);
    });

    testWidgets('7. AI返答がバブルに表示される', (tester) async {
      final mock = _MockAiChatService(replyText: 'タイヤは2.5kPaがおすすめです');
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextField, '車のことを何でも聞いてください'), 'タイヤの空気圧は？');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('タイヤは2.5kPaがおすすめです'), findsOneWidget);
    });
  });

  // =========================================================================
  group('AiChatScreen — Error handling', () {
    testWidgets('9. AI呼び出しが失敗するとエラーメッセージが表示される', (tester) async {
      final mock = _MockAiChatService(
        error: AppError.unknown('AI service unavailable'),
      );
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextField, '車のことを何でも聞いてください'), '失敗するメッセージ');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Error message should be shown in the chat
      expect(find.textContaining('エラー'), findsOneWidget);
    });
  });

  // =========================================================================
  group('AiChatScreen — Clear flow', () {
    testWidgets('8. クリアボタンで空状態に戻る', (tester) async {
      final mock = _MockAiChatService();
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      // Send a message first
      await tester.enterText(
          find.widgetWithText(TextField, '車のことを何でも聞いてください'), 'テストメッセージ');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Verify message is shown
      expect(find.text('テストメッセージ'), findsOneWidget);

      // Clear history
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      // Empty state should return
      expect(find.textContaining('クルマの専門家AIに'), findsOneWidget);
    });
  });

  // =========================================================================
  group('AiChatScreen — Input behavior', () {
    testWidgets('10. 空テキスト送信ではバブルが追加されない', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockAiChatService()));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(find.textContaining('クルマの専門家AIに'), findsOneWidget);
    });

    testWidgets('11. 送信後にテキストフィールドがクリアされる', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockAiChatService()));
      await tester.pump();
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextField, '車のことを何でも聞いてください'), '入力テスト');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      final tf = tester.widget<TextField>(
          find.widgetWithText(TextField, '車のことを何でも聞いてください'));
      expect(tf.controller?.text ?? '', isEmpty);
    });

    testWidgets('12. サジェストチップをタップするとメッセージが送信される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        _MockAiChatService(replyText: 'チップから送信されました'),
      ));
      await tester.pump();
      await tester.pump();

      // Tap the first suggestion chip
      await tester.tap(find.byType(ActionChip).first);
      await tester.pumpAndSettle();

      // AI reply should appear
      expect(find.text('チップから送信されました'), findsOneWidget);
    });
  });

  // =========================================================================
  group('AiChatScreen — Message display details', () {
    testWidgets('13. AIバブルにスマートトイアイコンが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockAiChatService()));
      await tester.pump();
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextField, '車のことを何でも聞いてください'), '返答を見る');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    });

    testWidgets('14. 空状態のサブタイトルテキストが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockAiChatService()));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('整備・トラブル・車検'), findsOneWidget);
    });

    testWidgets('15. 送信ボタンのtooltipが「送信」になっている', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockAiChatService()));
      await tester.pump();
      await tester.pump();

      final iconBtn = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send_rounded),
      );
      expect(iconBtn.tooltip, '送信');
    });

    testWidgets('16. クリアボタンのtooltipが「会話をクリア」になっている', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockAiChatService()));
      await tester.pump();
      await tester.pump();

      final iconBtn = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(iconBtn.tooltip, '会話をクリア');
    });
  });
}
