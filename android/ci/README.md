# android/ci

CI 用の google-services.json。Secret GOOGLE_SERVICES_JSON が無いときに
ci.yml / test_apk.yml / screenshots.yml がこれを android/app/google-services.json
へコピーする。アプリに埋め込まれて配られる値なので秘密ではない。

ここと lib/firebase_options.dart の android（appId / apiKey）が食い違うと、
ビルドは通るのに起動時に Firebase が別アプリを指して壊れる（2026-08-23 の
Android、2026-08 の iOS 白画面がこの形）。3 本のワークフローに同じ JSON を
貼っていた 2026-09-10 まで、screenshots.yml だけが再登録前の旧 App ID
（…android:cc5714538a…）と Web 用 API キーのまま取り残されていた。
片方を変えるときは必ず両方を見る。

