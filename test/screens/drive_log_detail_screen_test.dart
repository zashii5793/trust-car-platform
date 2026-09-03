// DriveLogDetailScreen Widget Tests
//
// カバレッジ監査（docs/reports/TEST_EXECUTION_2026-08-09_draft.md §1.1）で
// 優先度・高とされた画面テスト。
//
// GoogleMap（google_maps_flutter）はテスト環境にプラットフォームチャネルが
// 無く描画できないため、**地図の描画自体はテストしない**。経路データは常に
// 「2点未満」または「ぼかし後に空になる短経路」で構成し、_RoutePreview が
// GoogleMap を組み立てるパス（2点以上）には入らないようにしている。
//
// Coverage:
//   - 日記（タイトル・本文）フィールドの表示とプリフィル
//   - 保存ボタン → DriveLogService.updateDriveLog 呼び出し（モックで捕捉）
//   - 公開スイッチの表示・切替で isPublic が渡ること
//   - 非公開時のみ「公開したときの見え方を確認する」チェックが出ること
//   - waypoints 取得失敗でも画面全体がエラーにならないこと
//   - 経路が2点未満のとき「経路が記録されていません」表示
//   - Edge Cases（null プリフィル・空白タイトル・未ログイン・住所なし）

import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show GoogleMap;
import 'package:provider/provider.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/screens/drive/drive_log_detail_screen.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/drive_log_service.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/widgets/common/loading_indicator.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthService implements AuthService {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<Result<UserCredential, AppError>> signUpWithEmail(
          {required String email,
          required String password,
          String? displayName}) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<UserCredential, AppError>> signInWithEmail(
          {required String email, required String password}) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<UserCredential?, AppError>> signInWithGoogle() async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<void, AppError>> signOut() async => const Result.success(null);

  @override
  Future<Result<AppUser?, AppError>> getUserProfile() async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<void, AppError>> updateUserProfile(
          {String? displayName,
          String? photoUrl,
          String? prefecture,
          String? city}) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<void, AppError>> sendPasswordResetEmail(String email) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteAccount() async =>
      const Result.success(null);

  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeUser implements User {
  @override
  String get uid => 'test-uid';
  @override
  String? get displayName => 'Test User';
  @override
  String? get photoURL => null;
  @override
  String? get email => 'test@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _LoggedInAuthProvider extends AuthProvider {
  _LoggedInAuthProvider() : super(authService: MockAuthService());
  @override
  User? get firebaseUser => _FakeUser();
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
}

/// firebaseUser が null のままの AuthProvider（未ログイン相当）。
class _LoggedOutAuthProvider extends AuthProvider {
  _LoggedOutAuthProvider() : super(authService: MockAuthService());
  @override
  User? get firebaseUser => null;
}

class MockDriveLogService implements DriveLogService {
  Result<List<DriveWaypoint>, AppError> waypointsResult =
      const Result.success([]);

  /// 設定すると updateDriveLog がこの結果を返す（失敗テスト用）。
  /// 未設定時は渡された内容を反映した DriveLog を success で返す。
  Result<DriveLog, AppError>? updateResultOverride;

  /// updateDriveLog のエコー元。テスト側で画面に渡したログと同じものを置く。
  DriveLog? sourceLog;

  int updateCallCount = 0;
  String? lastDriveLogId;
  String? lastUserId;
  String? lastTitle;
  String? lastDescription;
  bool? lastIsPublic;

  @override
  Future<Result<List<DriveWaypoint>, AppError>> getWaypoints(
          String driveLogId) async =>
      waypointsResult;

  @override
  Future<Result<DriveLog, AppError>> updateDriveLog({
    required String driveLogId,
    required String userId,
    String? title,
    String? description,
    List<String>? tags,
    bool? isPublic,
    List<String>? photoUrls,
    String? thumbnailUrl,
  }) async {
    updateCallCount++;
    lastDriveLogId = driveLogId;
    lastUserId = userId;
    lastTitle = title;
    lastDescription = description;
    lastIsPublic = isPublic;

    final override = updateResultOverride;
    if (override != null) return override;

    final base = sourceLog!;
    return Result.success(base.copyWith(
      title: title,
      description: description,
      tags: tags,
      isPublic: isPublic,
      photoUrls: photoUrls,
      thumbnailUrl: thumbnailUrl,
      updatedAt: DateTime.now(),
    ));
  }

  // Unimplemented (not needed for screen tests)
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 写真アップロード導線でしか使われないため、呼ばれない前提のスタブ。
class _StubFirebaseService implements FirebaseService {
  @override
  Future<Result<bool, AppError>> hasAnyMaintenanceRecord() async =>
      const Result.success(false);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

DriveLog _makeLog({
  String id = 'log1',
  String userId = 'test-uid',
  String? title = '箱根の紅葉',
  String? description = 'ワインディングが最高だった',
  bool isPublic = false,
  String? startAddress = '東京都世田谷区北沢2-1-3',
  String? endAddress = '神奈川県足柄下郡箱根町1-2',
  List<String> photoUrls = const [],
}) {
  final start = DateTime(2026, 8, 1, 10, 0);
  return DriveLog(
    id: id,
    userId: userId,
    status: DriveLogStatus.completed,
    title: title,
    description: description,
    startAddress: startAddress,
    endAddress: endAddress,
    startTime: start,
    endTime: start.add(const Duration(hours: 2)),
    statistics: const DriveStatistics(
      totalDistance: 85.0,
      totalDuration: 7200,
      averageSpeed: 42.5,
      maxSpeed: 80.0,
    ),
    isPublic: isPublic,
    photoUrls: photoUrls,
    createdAt: start,
    updatedAt: start,
  );
}

DriveWaypoint _waypoint(double latitude, double longitude, {int secs = 0}) =>
    DriveWaypoint(
      location: GeoPoint2D(latitude: latitude, longitude: longitude),
      timestamp: DateTime(2026, 8, 1, 10).add(Duration(seconds: secs)),
    );

/// 全点が両端から500m圏内に収まる短経路。公開時は全点ぼかされ空になる。
List<DriveWaypoint> _shortRouteNearHome() => [
      _waypoint(35.0000, 139.0000),
      _waypoint(35.0005, 139.0000, secs: 30),
      _waypoint(35.0010, 139.0000, secs: 60),
    ];

Widget _buildApp(DriveLog log, {AuthProvider? auth}) {
  return ChangeNotifierProvider<AuthProvider>(
    create: (_) => auth ?? _LoggedInAuthProvider(),
    child: MaterialApp(home: DriveLogDetailScreen(driveLog: log)),
  );
}

/// 全セクション（共有スイッチ含む）が1画面に収まる縦長サーフェスで pump する。
Future<void> _pumpScreen(
  WidgetTester tester,
  DriveLog log, {
  AuthProvider? auth,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_buildApp(log, auth: auth));
  // 1回目: waypoints 読み込み完了の rebuild
  await tester.pump();
}

Future<void> _saveAndSettle(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('drive_log_save_button')));
  await tester.pump(); // _isSaving = true
  await tester.pump(); // 保存完了の rebuild + SnackBar
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockDriveLogService service;

  setUp(() {
    service = MockDriveLogService();
    ServiceLocator.instance.override<DriveLogService>(service);
    ServiceLocator.instance.override<FirebaseService>(_StubFirebaseService());
  });

  tearDown(() {
    ServiceLocator.instance.unregister<DriveLogService>();
    ServiceLocator.instance.unregister<FirebaseService>();
  });

  group('DriveLogDetailScreen — 基本表示', () {
    testWidgets('AppBar タイトルと保存ボタンが表示される', (tester) async {
      final log = _makeLog();
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      expect(find.text('ドライブの記録'), findsOneWidget);
      expect(find.byKey(const Key('drive_log_save_button')), findsOneWidget);
    });

    testWidgets('経路読み込み中はローディング表示になる', (tester) async {
      final log = _makeLog();
      service.sourceLog = log;

      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // pump 1回のみ = _loadWaypoints の setState 前
      await tester.pumpWidget(_buildApp(log));

      expect(find.byType(AppLoadingCenter), findsOneWidget);
    });

    testWidgets('写真なしのとき「まだ写真がありません」と追加ボタンを表示する', (tester) async {
      final log = _makeLog(photoUrls: []);
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      expect(find.text('まだ写真がありません'), findsOneWidget);
      expect(
          find.byKey(const Key('drive_log_add_photo_button')), findsOneWidget);
    });
  });

  group('日記セクション', () {
    testWidgets('タイトル・本文フィールドが既存の値でプリフィルされる', (tester) async {
      final log = _makeLog(title: '箱根の紅葉', description: 'ワインディングが最高だった');
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      expect(find.byKey(const Key('drive_log_title_field')), findsOneWidget);
      expect(
          find.byKey(const Key('drive_log_description_field')), findsOneWidget);
      expect(find.text('箱根の紅葉'), findsOneWidget);
      expect(find.text('ワインディングが最高だった'), findsOneWidget);
    });

    testWidgets('保存ボタンで編集内容が updateDriveLog に渡る', (tester) async {
      final log = _makeLog(id: 'log1');
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      await tester.enterText(
          find.byKey(const Key('drive_log_title_field')), '伊豆スカイライン');
      await tester.enterText(
          find.byKey(const Key('drive_log_description_field')), '朝焼けがきれいだった');
      await _saveAndSettle(tester);

      expect(service.updateCallCount, 1);
      expect(service.lastDriveLogId, 'log1');
      expect(service.lastUserId, 'test-uid');
      expect(service.lastTitle, '伊豆スカイライン');
      expect(service.lastDescription, '朝焼けがきれいだった');
      // 保存ボタン経由では公開状態は変更しない
      expect(service.lastIsPublic, isNull);
      expect(find.text('保存しました'), findsOneWidget);
    });

    testWidgets('保存失敗時はエラー SnackBar が出て成功メッセージは出ない', (tester) async {
      final log = _makeLog();
      service.sourceLog = log;
      service.updateResultOverride =
          const Result.failure(AppError.network('接続失敗'));

      await _pumpScreen(tester, log);
      await _saveAndSettle(tester);

      expect(service.updateCallCount, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('保存しました'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('公開設定', () {
    testWidgets('公開スイッチが表示され、非公開ログでは OFF になっている', (tester) async {
      final log = _makeLog(isPublic: false);
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      final tile = tester.widget<SwitchListTile>(
          find.byKey(const Key('drive_log_public_switch')));
      expect(tile.value, isFalse);
    });

    testWidgets('スイッチONで isPublic: true が渡り、表示もONになる', (tester) async {
      final log = _makeLog(isPublic: false);
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      await tester.tap(find.byKey(const Key('drive_log_public_switch')));
      await tester.pump();
      await tester.pump();

      expect(service.updateCallCount, 1);
      expect(service.lastIsPublic, isTrue);

      final tile = tester.widget<SwitchListTile>(
          find.byKey(const Key('drive_log_public_switch')));
      expect(tile.value, isTrue);
      // 公開になったのでプレビュー用チェックは消える
      expect(find.byKey(const Key('drive_log_preview_public')), findsNothing);
    });

    testWidgets('公開ログでスイッチOFFにすると isPublic: false が渡る', (tester) async {
      final log = _makeLog(isPublic: true);
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      await tester.tap(find.byKey(const Key('drive_log_public_switch')));
      await tester.pump();
      await tester.pump();

      expect(service.lastIsPublic, isFalse);
      final tile = tester.widget<SwitchListTile>(
          find.byKey(const Key('drive_log_public_switch')));
      expect(tile.value, isFalse);
    });

    testWidgets('非公開時のみ「公開したときの見え方を確認する」チェックが出る', (tester) async {
      final log = _makeLog(isPublic: false);
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      expect(find.byKey(const Key('drive_log_preview_public')), findsOneWidget);
      expect(find.text('公開したときの見え方を確認する'), findsOneWidget);
    });

    testWidgets('公開ログではプレビュー用チェックを出さない', (tester) async {
      final log = _makeLog(isPublic: true);
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      expect(find.byKey(const Key('drive_log_preview_public')), findsNothing);
    });

    testWidgets('プレビューONで住所が市区町村に丸まり、保存は呼ばれない', (tester) async {
      final log = _makeLog(
        isPublic: false,
        startAddress: '東京都世田谷区北沢2-1-3',
      );
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      // プレビュー前は番地まで表示される
      expect(find.text('東京都世田谷区北沢2-1-3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('drive_log_preview_public')));
      await tester.pump();

      // 市区町村まで丸められ、番地は消える
      expect(find.text('東京都世田谷区'), findsOneWidget);
      expect(find.text('東京都世田谷区北沢2-1-3'), findsNothing);
      // 経路0点なので「公開できる経路が残っていません」に切り替わる
      expect(find.text('公開できる経路が残っていません'), findsOneWidget);
      // プレビューは表示だけで保存しない
      expect(service.updateCallCount, 0);
    });
  });

  group('経路セクション', () {
    testWidgets('経路0点のとき「経路が記録されていません」を表示し GoogleMap を出さない', (tester) async {
      final log = _makeLog();
      service.sourceLog = log;
      service.waypointsResult = const Result.success([]);

      await _pumpScreen(tester, log);

      expect(find.text('経路が記録されていません'), findsOneWidget);
      expect(find.text('0点の記録'), findsOneWidget);
      expect(find.byType(GoogleMap), findsNothing);
    });

    testWidgets('waypoints 取得失敗でも画面はエラーにならず、日記の編集・保存ができる', (tester) async {
      final log = _makeLog();
      service.sourceLog = log;
      service.waypointsResult = const Result.failure(AppError.network('接続失敗'));

      await _pumpScreen(tester, log);

      expect(tester.takeException(), isNull);
      // ローディングは終わり、経路は空扱いで表示される
      expect(find.byType(AppLoadingCenter), findsNothing);
      expect(find.text('経路が記録されていません'), findsOneWidget);

      // 日記は編集して保存できる
      await tester.enterText(
          find.byKey(const Key('drive_log_title_field')), '経路なしでも保存できる');
      await _saveAndSettle(tester);

      expect(service.lastTitle, '経路なしでも保存できる');
      expect(find.text('保存しました'), findsOneWidget);
    });

    testWidgets('公開ログでは自宅圏内だけの短経路が全点消え、1点も表示されない', (tester) async {
      final log = _makeLog(isPublic: true);
      service.sourceLog = log;
      service.waypointsResult = Result.success(_shortRouteNearHome());

      await _pumpScreen(tester, log);

      // ぼかし後 2点未満 → 空リスト。GoogleMap は組み立てられない。
      expect(find.text('公開できる経路が残っていません'), findsOneWidget);
      expect(find.text('0点の記録'), findsOneWidget);
      expect(find.byType(GoogleMap), findsNothing);
    });

    testWidgets('公開ログの住所は市区町村までに丸められる', (tester) async {
      final log = _makeLog(
        isPublic: true,
        startAddress: '東京都世田谷区北沢2-1-3',
        endAddress: '神奈川県足柄下郡箱根町1-2',
      );
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      expect(find.text('東京都世田谷区'), findsOneWidget);
      expect(find.text('神奈川県足柄下郡'), findsOneWidget);
      expect(find.text('東京都世田谷区北沢2-1-3'), findsNothing);
      expect(find.text('神奈川県足柄下郡箱根町1-2'), findsNothing);
    });
  });

  group('Edge Cases', () {
    testWidgets('経路が1点のみでも「経路が記録されていません」を表示する', (tester) async {
      final log = _makeLog();
      service.sourceLog = log;
      service.waypointsResult = Result.success([_waypoint(35.0, 139.0)]);

      await _pumpScreen(tester, log);

      expect(find.text('経路が記録されていません'), findsOneWidget);
      expect(find.text('1点の記録'), findsOneWidget);
      expect(find.byType(GoogleMap), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('タイトル・本文が null でも空欄でプリフィルされクラッシュしない', (tester) async {
      final log = _makeLog(title: null, description: null);
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('drive_log_title_field')), findsOneWidget);
      expect(
          find.byKey(const Key('drive_log_description_field')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('drive_log_title_field')), '後から書いた日記');
      await _saveAndSettle(tester);

      expect(service.lastTitle, '後から書いた日記');
    });

    testWidgets('空白のみのタイトルは trim され空文字で渡る', (tester) async {
      final log = _makeLog();
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      await tester.enterText(
          find.byKey(const Key('drive_log_title_field')), '   ');
      await _saveAndSettle(tester);

      expect(service.lastTitle, '');
    });

    testWidgets('未ログイン状態の保存は updateDriveLog を呼ばずエラー表示する', (tester) async {
      final log = _makeLog();
      service.sourceLog = log;

      await _pumpScreen(tester, log, auth: _LoggedOutAuthProvider());
      await _saveAndSettle(tester);

      expect(service.updateCallCount, 0);
      expect(find.text('ログインセッションが切れました。再ログインしてください'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('住所が null のとき「記録なし」を表示する', (tester) async {
      final log = _makeLog(startAddress: null, endAddress: null);
      service.sourceLog = log;

      await _pumpScreen(tester, log);

      expect(find.text('記録なし'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
