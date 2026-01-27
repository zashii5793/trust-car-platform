# デザインシステム

信頼を設計する - Trust Car Platform Design System

---

## デザイン原則

### 1. シンプルで直感的
最小限の操作で目的を達成できるUI。ユーザーが迷わず、ストレスなく使える。

### 2. 情報の透明性
ユーザーが判断に必要な情報を明確に提示。AIの提案には必ず「理由」を添える。

### 3. 信頼感のあるビジュアル
落ち着いた色使いと丁寧なアニメーション。プロフェッショナルで安心感のあるデザイン。

### 4. アクセシビリティ
全てのユーザーが快適に使える配慮。コントラスト比、タップターゲットサイズ、スクリーンリーダー対応。

---

## カラーパレット

### プライマリーカラー（ブランドカラー）

```
Primary (Deep Blue)
#1A4D8F - メインアクション、重要な要素
#2563B8 - Hover状態
#0D3A6F - Active状態

用途: CTA、選択状態、重要な通知
```

### セカンダリーカラー

```
Secondary (Trust Green)
#2D7A5F - 成功、完了、信頼
#43A881 - Hover状態
#1F5A45 - Active状態

用途: 成功メッセージ、完了状態、ポジティブなフィードバック
```

### ニュートラルカラー

```
Neutral Gray Scale
#1F2937 - Text Primary (濃いグレー)
#4B5563 - Text Secondary
#6B7280 - Text Tertiary
#9CA3AF - Border / Divider
#D1D5DB - Background Secondary
#F3F4F6 - Background Light
#FFFFFF - Background White
```

### セマンティックカラー

```
Success
#10B981 - 成功状態

Warning
#F59E0B - 注意喚起

Error
#EF4444 - エラー、削除

Info
#3B82F6 - 情報、ヒント
```

### カスタマイズ・SNS系カラー

```
Accent Colors
#8B5CF6 - カスタム提案
#EC4899 - コミュニティ・いいね
#F97316 - ドライブ・アクティビティ
```

---

## タイポグラフィ

### フォントファミリー

```
Primary: Noto Sans JP
- 日本語に最適化
- 可読性が高い
- Google Fontsから利用可能

Secondary: Inter (英数字)
- モダンで読みやすい
- 数字の視認性が良い
```

### フォントサイズとウェイト

```
Display Large
Size: 32px / Line Height: 40px / Weight: 700
用途: ページタイトル、重要な見出し

Display Medium
Size: 24px / Line Height: 32px / Weight: 600
用途: セクション見出し

Heading Large
Size: 20px / Line Height: 28px / Weight: 600
用途: カード見出し、サブセクション

Heading Medium
Size: 18px / Line Height: 26px / Weight: 600
用途: リスト項目見出し

Body Large
Size: 16px / Line Height: 24px / Weight: 400
用途: 本文（メイン）

Body Medium
Size: 14px / Line Height: 20px / Weight: 400
用途: 本文（サブ）、説明文

Body Small
Size: 12px / Line Height: 18px / Weight: 400
用途: キャプション、補足情報

Label
Size: 14px / Line Height: 20px / Weight: 500
用途: ボタンラベル、フォームラベル
```

---

## スペーシング

### 基本単位: 4px

```
XXS: 4px   - 最小の余白
XS:  8px   - タイトな余白
S:   12px  - 小さい余白
M:   16px  - 標準的な余白 ★デフォルト
L:   24px  - ゆとりのある余白
XL:  32px  - セクション間の余白
XXL: 48px  - 大きなセクション間
```

### 使用例

```dart
// パディング
const EdgeInsets.all(16)        // カード内部
const EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 12,
)                                // ボタン内部

// マージン
const SizedBox(height: 24)      // セクション間
const SizedBox(height: 12)      // リスト項目間
```

---

## コンポーネント

### ボタン

#### Primary Button
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFF1A4D8F),
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 12,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    elevation: 0,
  ),
  onPressed: () {},
  child: Text('登録する'),
)
```

#### Secondary Button
```dart
OutlinedButton(
  style: OutlinedButton.styleFrom(
    foregroundColor: Color(0xFF1A4D8F),
    side: BorderSide(
      color: Color(0xFF1A4D8F),
      width: 1.5,
    ),
    padding: EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 12,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
  onPressed: () {},
  child: Text('キャンセル'),
)
```

#### Text Button
```dart
TextButton(
  style: TextButton.styleFrom(
    foregroundColor: Color(0xFF1A4D8F),
    padding: EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
  ),
  onPressed: () {},
  child: Text('詳細を見る'),
)
```

### カード

```dart
Card(
  elevation: 2,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // コンテンツ
      ],
    ),
  ),
)
```

### フォーム要素

#### Text Field
```dart
TextField(
  decoration: InputDecoration(
    labelText: 'メーカー',
    hintText: '例: トヨタ',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    contentPadding: EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
  ),
)
```

#### Dropdown
```dart
DropdownButtonFormField(
  decoration: InputDecoration(
    labelText: 'タイプ',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
  items: [
    DropdownMenuItem(value: 'repair', child: Text('修理')),
    DropdownMenuItem(value: 'inspection', child: Text('点検')),
  ],
  onChanged: (value) {},
)
```

### アイコン

```dart
// 標準サイズ
Icon(
  Icons.directions_car,
  size: 24,
  color: Color(0xFF1A4D8F),
)

// 大きめ
Icon(
  Icons.check_circle,
  size: 48,
  color: Color(0xFF2D7A5F),
)
```

---

## レイアウトパターン

### 画面構成

```
┌──────────────────────┐
│   App Bar (64px)     │
├──────────────────────┤
│                      │
│   Content            │
│   (Scrollable)       │
│                      │
│   Padding: 16px      │
│                      │
├──────────────────────┤
│   Bottom Nav (56px)  │ ※必要に応じて
└──────────────────────┘
```

### カードリスト

```dart
ListView.builder(
  padding: EdgeInsets.all(16),
  itemBuilder: (context, index) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: ListTile(
        // コンテンツ
      ),
    );
  },
)
```

### グリッド

```dart
GridView.count(
  crossAxisCount: 2,
  padding: EdgeInsets.all(16),
  crossAxisSpacing: 16,
  mainAxisSpacing: 16,
  children: [
    // グリッドアイテム
  ],
)
```

---

## アニメーション

### トランジション

```dart
// ページ遷移
PageRouteBuilder(
  pageBuilder: (context, animation, secondaryAnimation) => NextPage(),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  },
  transitionDuration: Duration(milliseconds: 300),
)
```

### ローディング

```dart
// Circular Progress
Center(
  child: CircularProgressIndicator(
    color: Color(0xFF1A4D8F),
  ),
)

// Skeleton Loading
Shimmer.fromColors(
  baseColor: Colors.grey[300]!,
  highlightColor: Colors.grey[100]!,
  child: Container(
    height: 100,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
  ),
)
```

### ホバー・タップエフェクト

```dart
// インタラクティブ要素
InkWell(
  onTap: () {},
  borderRadius: BorderRadius.circular(8),
  child: Container(
    // コンテンツ
  ),
)
```

---

## 状態表示

### 空状態（Empty State）

```dart
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.directions_car,
        size: 80,
        color: Colors.grey[300],
      ),
      SizedBox(height: 16),
      Text(
        '車両が登録されていません',
        style: TextStyle(
          fontSize: 18,
          color: Colors.grey[600],
        ),
      ),
      SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(Icons.add),
        label: Text('車両を登録'),
      ),
    ],
  ),
)
```

### エラー状態

```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Color(0xFFFEE2E2),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Row(
    children: [
      Icon(Icons.error, color: Color(0xFFEF4444)),
      SizedBox(width: 12),
      Expanded(
        child: Text(
          'エラーメッセージ',
          style: TextStyle(color: Color(0xFFEF4444)),
        ),
      ),
    ],
  ),
)
```

### 成功状態

```dart
SnackBar(
  content: Row(
    children: [
      Icon(Icons.check_circle, color: Colors.white),
      SizedBox(width: 12),
      Text('登録が完了しました'),
    ],
  ),
  backgroundColor: Color(0xFF10B981),
  behavior: SnackBarBehavior.floating,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  ),
)
```

---

## アクセシビリティ

### コントラスト比

- テキスト（通常）: 最低 4.5:1
- テキスト（大）: 最低 3:1
- UI要素: 最低 3:1

### タップターゲット

- 最小サイズ: 48x48 dp
- 推奨サイズ: 56x56 dp

### スクリーンリーダー対応

```dart
Semantics(
  label: '車両を登録',
  button: true,
  child: IconButton(
    icon: Icon(Icons.add),
    onPressed: () {},
  ),
)
```

---

## レスポンシブデザイン

### ブレークポイント

```dart
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

// 使用例
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < Breakpoints.mobile) {
      return MobileLayout();
    } else if (constraints.maxWidth < Breakpoints.tablet) {
      return TabletLayout();
    } else {
      return DesktopLayout();
    }
  },
)
```

---

## ダークモード対応

### カラーパレット（ダークモード）

```
Background
#121212 - Primary Background
#1E1E1E - Secondary Background
#2C2C2C - Card Background

Text
#FFFFFF - Primary Text
#B3B3B3 - Secondary Text
#808080 - Tertiary Text

Primary
#4A90E2 - Lighter Blue for Dark Mode
```

### 実装

```dart
MaterialApp(
  theme: ThemeData(
    brightness: Brightness.light,
    primaryColor: Color(0xFF1A4D8F),
    // ... ライトモード設定
  ),
  darkTheme: ThemeData(
    brightness: Brightness.dark,
    primaryColor: Color(0xFF4A90E2),
    // ... ダークモード設定
  ),
  themeMode: ThemeMode.system,
)
```

---

## 画像・アイコン

### 画像最適化

- フォーマット: WebP推奨（フォールバック: JPEG/PNG）
- サムネイル: 最大 300x300px
- 詳細画像: 最大 1200x1200px
- 圧縮率: 85-90%

### アイコンセット

Material Icons使用

**主要アイコン**
- `directions_car` - 車両
- `build` - 修理
- `search` - 点検
- `settings` - 消耗品
- `verified` - 車検
- `notifications` - 通知
- `person` - プロフィール
- `map` - ドライブ
- `group` - コミュニティ

---

## 実装ガイドライン

### テーマ設定

```dart
// lib/utils/theme.dart
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Color(0xFF1A4D8F),
      brightness: Brightness.light,
    ),
    fontFamily: 'Noto Sans JP',
    // その他の設定...
  );
}
```

### カラー定数

```dart
// lib/utils/colors.dart
class AppColors {
  static const primary = Color(0xFF1A4D8F);
  static const primaryHover = Color(0xFF2563B8);
  static const secondary = Color(0xFF2D7A5F);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
}
```

### タイポグラフィ定数

```dart
// lib/utils/text_styles.dart
class AppTextStyles {
  static const displayLarge = TextStyle(
    fontSize: 32,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );
  
  static const bodyLarge = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
  // その他...
}
```

---

## チェックリスト

### デザインレビュー時

- [ ] カラーパレットに準拠しているか
- [ ] タイポグラフィが統一されているか
- [ ] スペーシングが適切か
- [ ] コントラスト比が十分か
- [ ] タップターゲットサイズが適切か
- [ ] アニメーションが滑らかか
- [ ] ダークモード対応ができているか
- [ ] レスポンシブデザインになっているか

### 実装時

- [ ] テーマ設定を使用しているか
- [ ] カラー定数を使用しているか
- [ ] Semanticsを適切に設定しているか
- [ ] 画像が最適化されているか
- [ ] ローディング状態を実装しているか
- [ ] エラー処理を実装しているか

---

## 参考リンク

- [Material Design 3](https://m3.material.io/)
- [Flutter Design Patterns](https://flutter.dev/docs/cookbook)
- [WCAG 2.1](https://www.w3.org/WAI/WCAG21/quickref/)
