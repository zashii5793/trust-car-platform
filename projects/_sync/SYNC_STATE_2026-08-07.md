# 外部状態の取り込み — 2026-08-07 実測

| 項目 | 内容 |
|---|---|
| 対象 | ① Google Drive 最近の更新 ② GitHub 未クローズPR（CI状態つき） |
| 状態 | **下書き（未承認）** — Drive へは未配置 |
| 実測時刻 | 2026-08-07 21:30〜21:40 JST |
| 前回値の再利用 | **なし。全数値を本セッションで取り直した** |

---

## 0. 先に報告 — 指示された取り込み先が存在しません

ご指示は「`company.yaml` の `external.*` を見て、`sync_state.py` に流す」でしたが、
**どちらのファイルも見つかりませんでした。** 探索範囲と結果は以下です。

```
 探索対象                                        結果
 ─────────────────────────────────────────────  ──────
 zashii5793/trust-car-platform（作業リポジトリ）   なし
 zashii5793/zaxel（clone して全ファイル確認）       なし ※中身は静的サイト
                                                  index.html / minutes.html /
                                                  scripts/morning_todo.py のみ
 このコンテナのファイルシステム全体                  なし
 Google Drive（title 検索: company / sync_state）   なし
```

`zaxel` リポジトリは会社サイトの静的HTMLであり、案件オーケストレーションの
リポジトリではありませんでした。

### これが判断に与える影響（重要）

**`blocks_forbidden` の中身が分かりません。**

ご指示には「⚠️ blocks_forbidden に当たるものは開いても転記しないこと」とありましたが、
その一覧が `company.yaml` にある以上、**何が禁止対象なのかを確認する手段がありません。**

そこで本レポートは **転記を最小限に寄せた安全側の運用**にしています。

```
 やったこと    ファイル名・更新時刻・種別・所有者（メタデータ）だけを記録
 やらないこと  本文・数値・氏名など中身の転記
```

Drive 側は後述のとおり**個人情報を含む可能性が高い**ファイル群が上位を占めたため、
この判断は結果的に必要でした。`company.yaml` を頂ければ正規の基準で取り直します。

### 代替の置き場所

`sync_state.py` が無いため、本ファイル
（`projects/_sync/SYNC_STATE_2026-08-07.md`）に出力しました。
PR #114 が確立した `projects/<案件名>/` の下書き規約に合わせています。

---

## 1. drive.recent — Google Drive 最近の更新

`list_recent_files`（orderBy=lastModified）で上位25件を取得。

### 内訳（種別）

```
 Google スプレッドシート   21 件
 PowerPoint (.pptx)        1 件
 動画 (mp4)                1 件
 画像 (jpeg)               1 件
 ─────────────────────  ────
 合計                     25 件
```

### 内訳（内容カテゴリ）— 中身は転記していません

```
 ココグラム（プログラミング教室）校舎運営      25 件 / 25 件
   ├ シフト表・カレンダー・管理シート
   ├ 授業コメント記入ツール・コメント対応
   ├ 席次表・出席者リスト
   ├ 体験会シート・配布物管理シート
   └ 修了証・提出課題・校舎写真
```

対象校舎（ファイル名から判別できたもの）:
水戸 / 仙台青葉 / 新潟 / 甲府 / 船橋 / 津田沼 / 春日 / 名古屋 / 三鷹 /
鹿児島中央 / 松山 / 市ヶ尾 / 筑紫野 / 太白、および CPC本部。

更新レンジ: 2026-08-07 06:27 〜 21:31 JST（**全25件が本日中の更新**）。

### 転記しなかった理由

上位25件には **出席者リスト・席次表・授業コメント・提出課題動画・校舎入口写真**が
含まれます。受講生・保護者・スタッフの個人情報にあたる可能性が高く、
`blocks_forbidden` が確認できない状態で中身を転記するのは危険と判断しました。

**ファイルを開いての内容取得は行っていません**（メタデータのみで判定）。

### 本日いちばん重要な発見

```
 4案件（trust-car-platform / faq-platform / note-articles /
        claude-tts-extension）に関係する更新     0 件 / 25 件
```

**Drive の直近の活動は、全量がココグラム校舎運営です。**
案件フォルダ（`02_プロジェクト管理/` 配下）は直近25件に一切現れていません。

### 案件フォルダの実在確認

ご指定URL `1XC-No-iHHvtv8LYpsWiCNZYzccAP4exZ` は、それ自体が
`02_プロジェクト管理` フォルダでした。直下は **2フォルダのみ**です。

```
 02_プロジェクト管理/            ← ご指定のURL
   ├ trust-car-platform/        （1FBN0vu7ZJK9DfZRHXt7nfNNQ2iJ3qEjw）
   └ FAQ_Platform_v2/           （1mhRmR7-_XHdWjjAtGgtBPLdnmsbnxjnp）
```

つまり成果物の宛先として指示された 4フォルダのうち、**3つが未作成**です。

```
 02_プロジェクト管理/trust-car-platform/       存在する
 02_プロジェクト管理/faq-platform/             未作成（近いのは FAQ_Platform_v2）
 02_プロジェクト管理/note-articles/            未作成
 02_プロジェクト管理/claude-tts-extension/     未作成
 各 _log/ サブフォルダ                          いずれも未作成
```

> ⚠️ **`02_プロジェクト管理` という名前のフォルダは Drive 上に2つあります。**
> ご指定URLのもの（親 `1lu9X43...`）と、別の親 `14bz6SXa...` を持つ別フォルダ
> （`1BkOFbPVFthCntW9Ea5I3ARncDZOmPWYe`）です。
> 承認後に配置する際、**どちらを正とするかの確認が要ります。**

---

## 2. github.prs — 未クローズPR（CI状態つき）

### 件数（実測）

```
 zashii5793/trust-car-platform   未クローズPR   9 件
```

> ご指示の材料欄には「未クローズPR **7件**」とありましたが、**実測は9件**でした。
> 参考までに PR #114 の作業ログ（2026-08-05 時点）では **6件**と記録されています。
> 6件（8/5）→ 9件（8/7）と増えており、**7 はどの時点の値とも一致しません。**

対象リポジトリは trust-car-platform のみです。`company.yaml` の
`external.github` が読めないため、**他にどのリポジトリが対象なのか確定できません。**
本セッションの GitHub API スコープも trust-car-platform に限定されていました
（faq_platform への API 呼び出しは `not configured for this session` で拒否）。

### 一覧（`origin/main` = `f070f2e` に対する実測）

```
 PR    behind ahead merge     CI              最終CI     内容
 ────  ────── ───── ────────  ──────────────  ─────────  ──────────────────────────
 #118    0      2   clean     緑 4/6          08-06      RevenueCat APIキー環境変数化
                                (2 skipped)
 #116    0      9   clean     ⏳ 実行中        08-07※    ナビ上段化/ダッシュボード縮小
 #114    2      1   clean     緑 4/4          08-05      faq-platform棚卸し＋全部署諮問
 #111    4      1   clean     緑 8/8          08-05      Webフィードバック Batch 2
 #106   16      2   CONFLICT  緑 8/8          08-02      近隣工場 Google Maps 地図表示
 #98    16      4   CONFLICT  緑 8/8          07-28      AppTextField 統一（Issue #29）
 #90    16      2   clean     緑 8/8          07-20      愛車カルテ PDF出力（Issue #64）
 #88    16      1   clean     🔴 1件失敗       07-18      Webプレビュー自動デプロイ
                                (8成功/1失敗)
 #61    21      6   CONFLICT  緑 8/8          06-28      ローンチ前データ運用の強化
```

※ #116 の `Analyze & Test` は 2026-08-07 21:32 開始で、本レポート作成時点で
`in_progress`。結果は未確定です。

### CI 集計

```
 全チェック成功      7 件（#118 #114 #111 #106 #98 #90 #61）
 失敗を含む          1 件（#88）
 実行中              1 件（#116）
```

**唯一の赤は #88 の `build_and_deploy`**（run 29642021794 / 2026-07-18）。
Firebase Hosting へのデプロイジョブで、`FIREBASE_SERVICE_ACCOUNT` Secret が
未登録のため失敗しているとみられます（＝コードの不具合ではなく人間作業待ち）。

### ⚠️ この「緑」は現 main に対する緑ではありません

上表の CI 結果は **各PRのヘッドSHAが作られた当時**のものです。

```
 #61 の緑    2026-06-28 の main に対する緑    現 main から 21 コミット遅れ
 #88 の結果  2026-07-18                       16 コミット遅れ
 #90 の緑    2026-07-20                       16 コミット遅れ
 #98 の緑    2026-07-28                       16 コミット遅れ
 #106 の緑   2026-08-02                       16 コミット遅れ
```

**「いま緑」と「現 main にのせて緑」は別物です。**
後者を知るには rebase して回し直すしかありません
（→ `projects/trust-car-platform/PR_REBASE_PLAN_2026-08-07.md`）。

### マージ可否（`git merge-tree --write-tree` 実測）

```
 clean      6 件   #118 #116 #114 #111 #90 #88
 CONFLICT   3 件   #106 #98 #61
```

### オーナー決裁との差分（要確認）

`docs/OPEN_PR_TRIAGE_2026-08-05.md` のオーナー決定では、
**#106 は「クローズする30件」に含まれていました**が、**現在も open です。**

```
 決裁（8/05）  #106 → CLOSE
 実測（8/07）  #106 → open・16コミット遅れ・CONFLICT
```

PR #114 の作業ログ（8/05）が挙げた open 一覧にも #106 は入っていないため、
**8/05 以降に再オープンされたか、クローズ作業が漏れた**かのいずれかです。
どちらなのかは判断が要ります。

---

## 3. 実測に使ったコマンド・API（再現用）

```
 Drive    mcp__Google_Drive__list_recent_files (orderBy=lastModified, pageSize=25)
          mcp__Google_Drive__search_files (parentId = '1XC-No-...')
 GitHub   mcp__github__list_pull_requests (state=open, perPage=100)
          mcp__github__pull_request_read (method=get_check_runs) × 9
 Git      git fetch origin main <9 branches>
          git rev-list --count <branch>..origin/main     （behind）
          git rev-list --count origin/main..<branch>     （ahead）
          git merge-tree --write-tree origin/main <branch>（merge 可否）
```

---

## 4. 本取り込みの限界（明示）

- **`company.yaml` が無いため、対象範囲は推定**です。Drive は「最近の更新」全体、
  GitHub は本セッションのスコープ内（trust-car-platform のみ）に限りました。
  他に対象リポジトリがあれば取りこぼしています。
- **`blocks_forbidden` 不明のため、Drive はメタデータのみ**とし、本文を開いていません。
  正規の基準を頂ければ取り直します。
- **Drive の「最近の更新」は上位25件のみ**。ページングしていないため、
  25件より前の更新は見ていません。
- **#116 の CI は実行中**で、結果は未確定です。
