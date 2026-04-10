#!/usr/bin/env dart
// ignore_for_file: avoid_print
/// Shop Seed Data — Firestore 登録スクリプト
///
/// Usage:
///   dart scripts/seed_shops.dart [--dry-run] [--emulator]
///
/// Options:
///   --dry-run    Firestore に書かず、登録予定データを標準出力に表示する
///   --emulator   Firebase Emulator (localhost:8080) に接続する
///
/// Requirements:
///   - GOOGLE_APPLICATION_CREDENTIALS に Firebase サービスアカウントキーを設定
///   - または --emulator フラグで Emulator に接続
///
/// Example:
///   # Emulator で動作確認
///   firebase emulators:start --only firestore
///   dart scripts/seed_shops.dart --dry-run
///   dart scripts/seed_shops.dart --emulator
///
///   # 本番に登録（要サービスアカウントキー設定）
///   export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json
///   dart scripts/seed_shops.dart

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// シードデータ定義
// ---------------------------------------------------------------------------

final List<Map<String, dynamic>> shopSeeds = [
  {
    // ------------------------------------------------------------------
    // タカヤモーター株式会社
    // 岡山市中区の整備工場。創業1965年、約60年の実績を持つ地域密着の自動車サービス会社。
    // ------------------------------------------------------------------
    'id': 'shop_takaya_motor_okayama',
    'name': 'タカヤモーター株式会社',
    'type': 'maintenanceShop',
    'description':
        '創業1965年（昭和40年）。約60年の実績と信頼。車検・点検・整備から新車・中古車販売、カーリースまでトータルカーライフをサポートします。「お客様満足No.1」を目指し、質の高いカーサービスをご提供しています。',
    'logoUrl': null,
    'imageUrls': <String>[],

    // 連絡先
    'phone': null, // TODO: 正式な電話番号を記入してください
    'email': null, // TODO: 正式なメールアドレスを記入してください
    'website': 'https://www.takayagroup.co.jp/',

    // 所在地
    'prefecture': '岡山県',
    'city': '岡山市中区',
    'address': null, // TODO: 番地まで記入してください (例: 中区倉田○○番地)
    'location': null, // TODO: GeoPoint(緯度, 経度) を設定してください

    // サービス
    'services': [
      'inspection',   // 車検
      'maintenance',  // 整備・点検
      'repair',       // 修理
      'bodyWork',     // 板金・塗装
      'purchase',     // 車両購入（新車・中古車販売）
      'rental',       // レンタカー
      'insurance',    // 保険
    ],
    'supportedMakerIds': <String>[], // 空 = 全メーカー対応

    // 営業時間 (0=日, 1=月, 2=火, 3=水, 4=木, 5=金, 6=土)
    'businessHours': {
      '0': {'openTime': null, 'closeTime': null, 'isClosed': true},  // 日曜
      '1': {'openTime': '09:00', 'closeTime': '18:00', 'isClosed': false},
      '2': {'openTime': '09:00', 'closeTime': '18:00', 'isClosed': false},
      '3': {'openTime': '09:00', 'closeTime': '18:00', 'isClosed': false},
      '4': {'openTime': '09:00', 'closeTime': '18:00', 'isClosed': false},
      '5': {'openTime': '09:00', 'closeTime': '18:00', 'isClosed': false},
      '6': {'openTime': '09:00', 'closeTime': '17:00', 'isClosed': false},
    },
    'businessHoursNote': null, // TODO: 定休日・祝日対応など確認して記入

    // 評価（初期値）
    'rating': null,
    'reviewCount': 0,

    // ステータス
    'isVerified': true,   // オーナー確認済み
    'isFeatured': true,   // トップ表示
    'isActive': true,
  },
];

// ---------------------------------------------------------------------------
// エントリポイント
// ---------------------------------------------------------------------------

void main(List<String> args) async {
  final isDryRun = args.contains('--dry-run');
  final useEmulator = args.contains('--emulator');

  print('=== Shop Seed Script ===');
  print('dry-run  : $isDryRun');
  print('emulator : $useEmulator');
  print('登録件数  : ${shopSeeds.length}');
  print('');

  if (isDryRun) {
    print('--- [DRY RUN] 登録予定データ ---');
    for (final shop in shopSeeds) {
      final encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(shop));
      print('');
    }
    print('--- [DRY RUN] 完了（Firestore への書き込みは行っていません）---');
    return;
  }

  // ----- Firestore 書き込み -----
  // Flutter プロジェクトでは Firebase Admin SDK (Node.js) または
  // Firestore REST API 経由での書き込みが必要です。
  //
  // 推奨手順:
  //   1. firebase-admin を使った Node.js スクリプト、または
  //   2. Firebase Emulator の import/export 機能を使う
  //
  // 以下は Firebase Emulator 使用時のコマンド例:
  //   firebase emulators:export ./emulator_data
  //   # emulator_data/firestore_export 以下のデータを手動編集して import
  //
  // または Node.js スクリプト (scripts/seed_shops.js) を使ってください。
  print('');
  print('[INFO] Dart から直接 Firestore に書き込む場合は、');
  print('       firebase_admin が必要です。');
  print('       以下の Node.js スクリプトをご利用ください:');
  print('         node scripts/seed_shops.js');
  print('');
  print('       または --dry-run で JSON を確認し、');
  print('       Firebase Console から手動インポートも可能です。');

  exit(0);
}
