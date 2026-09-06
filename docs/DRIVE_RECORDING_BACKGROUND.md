# 走行記録をバックグラウンドで続けるか（P2-12 の判断材料）

**作成**: 2026-09-04
**対象**: `docs/HUMAN_TASKS.md` P2-12

---

## まず、A は実装済みです

HUMAN_TASKS は「現状は停止する」「A / B / C から選ぶ」と書いていますが、
**A（現状のまま出す・画面に明記）は既に入っています。**

`drive_recording_screen.dart:249-284` の `_ForegroundOnlyNotice`:

> 記録中はこの画面を開いたままにしてください。画面をロックしたり他のアプリに
> 切り替えると、記録が止まります。

`Info.plist` にも意図がコメントで残っています（`ios/Runner/Info.plist:31-34`）。

> background location is not used, so the Always description is intentionally
> omitted to avoid App Review scrutiny

**したがって判断すべきは「A のままにするか、B か C へ進むか」です。**

## いまの実装

| 項目 | 状態 |
|---|---|
| 位置の取得 | `Geolocator.getPositionStream`（`drive_recording_provider.dart:315`） |
| 精度 | `LocationAccuracy.high`、`distanceFilter: 5`（5m未満の揺れは無視） |
| Android の権限 | `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` のみ。**`FOREGROUND_SERVICE` なし** |
| iOS の権限 | `NSLocationWhenInUseUsageDescription` のみ。**`UIBackgroundModes` なし** |
| 画面スリープ抑止 | **なし**（`wakelock` の依存も無し） |

**止まる条件**: 画面ロック、他アプリへの切り替え、ホームに戻る。

## 選択肢

### A. このまま（変更なし）

- **コスト**: ゼロ
- **問題**: 運転中はスマホを見ないので、**自動ロックが働いて止まる**のが最大の
  失敗要因。案内文を読んでいても、ロックを切るのは手間
- ソフトローンチで「実際にどれくらい使われるか」を見るには足りる

### B. 記録中だけ画面を消さない（wakelock）

- **やること**: `wakelock_plus` を追加し、記録の開始で `enable()`、停止・画面離脱で
  `disable()`。**アプリの設定は何も変わらない**（権限もストア申請も増えない）
- **効くところ**: 自動ロックで止まるのを防げる。**最大の失敗要因が消えます**
- **効かないところ**: ユーザーが自分でホームに戻る／他アプリへ切り替えると止まる
- **副作用**: 画面が点きっぱなしなのでバッテリーを食う。**車載ホルダーで充電しながら
  使う前提**なら実害は小さい。夏場の車内は熱くなるので、そこは実機で見たい
- **実装コスト**: 小（1〜2時間）。**ストア審査のリスクは増えません**

### C. 正式にバックグラウンド対応

- **iOS**: `UIBackgroundModes: location` ＋ Xcode の Capability。
  **`Always` 権限は不要**で、`WhenInUse` のままでも「前面で開始 → 背面で継続」は
  できます（背面から**開始**するには Always が要る）。
  画面上部に青いバーが出ます
- **Android**: `FOREGROUND_SERVICE` ＋ `FOREGROUND_SERVICE_LOCATION` 権限と、
  常駐通知つきのサービス
- **審査リスク**: **ガイドライン 2.5.4**。「バックグラウンド位置情報が必要な、
  ユーザーに見える機能」を説明できないとリジェクトされます。**ドライブ記録は
  その説明が成立しやすい用途**（ユーザー自身が明示的に開始・停止する）ですが、
  初回申請で追加質問が来る前提で見ておくべきです
- **実装コスト**: 中〜大（3〜5日）。Android の Foreground Service は
  `flutter_background_service` などを挟むのが現実的。**電池最適化の除外**を
  ユーザーに促す導線も要ります

## 比較

| | A | B | C |
|---|---|---|---|
| 実装 | 済 | 1〜2時間 | 3〜5日 |
| 自動ロックで止まる | **止まる** | 止まらない | 止まらない |
| 他アプリ切り替えで止まる | 止まる | 止まる | 止まらない |
| ストア審査 | 影響なし | 影響なし | **2.5.4 の説明が要る** |
| バッテリー | — | 画面が点きっぱなし | 位置取得が続く |

## 勧め

**B を入れて出し、C はソフトローンチの実績を見てから判断する**のが現実的だと
考えます。理由は3つです。

1. **止まる原因のほとんどは自動ロック**で、B はそこだけを潰せる
2. **B はストア審査に一切影響しない**。C は初回申請の不確実性を上げる
3. **C が要るかどうかは、実際にドライブログが使われるか次第**。使われない機能の
   ために審査リスクを取る理由はない

ただし、**車載ホルダー・充電なしで長距離を記録する使い方**が主なら、B では
バッテリーが持たず C が要ります。**想定している使われ方によります。**

## B を選んだ場合にやること

1. `pubspec.yaml` に `wakelock_plus` を追加
2. `DriveRecordingProvider` の開始・停止で `WakelockPlus.enable()` / `disable()`
3. 画面を離れるとき（`dispose`）にも必ず `disable()`（記録中に戻るボタンで
   抜けたときの取りこぼしを防ぐ）
4. `_ForegroundOnlyNotice` の文言を実態に合わせる
   （「画面をロックしたり」→「他のアプリに切り替えると」だけに）
5. 実機で**発熱とバッテリーの減り**を確認（`docs/DEVICE_TEST_CHECKLIST.md` に追記）

**AI 側で実装できます。** 方針が決まったら言ってください。

---

## 参考

- [allowsBackgroundLocationUpdates - Apple Developer](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates)
- [Handling location updates in the background - Apple Developer](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background)
- [App rejected guidelines performance 2.5.4 - UIBackgroundModes（Apple Developer Forums）](https://developer.apple.com/forums/thread/771202)
