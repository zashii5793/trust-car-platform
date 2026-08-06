# trust-car-platform

Flutter 製車両管理アプリ。Firebase（Auth, Firestore, Storage）バックエンド。

## 環境変数（.env / --dart-define）

APIキー等のシークレットはコードに直書きせず、環境変数で注入します。

1. テンプレートをコピーして値を埋める（`.env` は git 管理外）:

   ```bash
   cp .env.example .env
   ```

2. 値の供給方法（先に見つかった非空値が優先）:

   | 方法 | 用途 | 例 |
   |------|------|-----|
   | `--dart-define` | CI / リリース（推奨・ファイル不要） | `flutter build apk --dart-define=REVENUE_CAT_API_KEY_ANDROID=goog_xxx` |
   | `.env`（flutter_dotenv） | ローカル開発 | `.env` に記述して `flutter run` |

### 変数一覧

| 変数 | 用途 | 参照 |
|------|------|------|
| `FIREBASE_FUNCTIONS_URL` | AIチャットの Cloud Functions ベースURL | `lib/services/ai_chat_service.dart` |
| `REVENUE_CAT_API_KEY_IOS` | RevenueCat 公開SDKキー（iOS） | `lib/services/revenue_cat_service.dart` |
| `REVENUE_CAT_API_KEY_ANDROID` | RevenueCat 公開SDKキー（Android） | `lib/services/revenue_cat_service.dart` |
| `MAPS_API_KEY` | Google Maps（予定・Issue #41 / #43） | 未実装 |

> ⚠️ 実キーは絶対にコミットしないでください。`.env` は `.gitignore` 済み、`.env.example` のみ追跡対象です。

### 補足: `.env` を runtime で使う場合

`.env`（dotenv）を実行時に読み込むには、`.env` を `pubspec.yaml` の `flutter: assets:` に登録し、
`main.dart` 起動時に `await dotenv.load(fileName: '.env')` を呼ぶ配線が別途必要です
（ビルド時にファイルが存在しないと `flutter build` が失敗するため、CI では `--dart-define` を推奨）。
