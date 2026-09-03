import 'package:flutter/material.dart';

import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../services/feedback_service.dart';
import 'feedback_screen.dart';

/// ヘルプ画面
///
/// 以前はプロフィールの「ヘルプ」から GitHub Pages を外部ブラウザで開いていたが、
/// そこに公開されているのは開発者向けの README（flutter run の手順や
/// コントリビューション規約）で、利用者の役に立たなかった。
/// アプリ内に置くことで、オフラインでも読めて外部サイトの整備も不要になる。
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, this.userId});

  /// 送信元の特定に使う。未ログインなら null のままでよい（フィードバック
  /// 画面側がログインを促す）。
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('ヘルプ')),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          Text(
            'よくある質問',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '知りたいことが見つからないときは、下部の問い合わせ先までご連絡ください。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          for (final section in _sections) ...[
            _HelpSectionHeader(title: section.title),
            for (final item in section.items)
              _HelpTile(question: item.question, answer: item.answer),
            const SizedBox(height: 20),
          ],
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'お問い合わせ',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '解決しない場合は、下のボタンからアプリ内でお知らせください。'
            'ご利用の端末とアプリのバージョンは自動で添えられるので、'
            '困っている内容だけ書いていただければ大丈夫です。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          // メールだけの導線では、細かい気づき（「車検の通知が遅い」など）が
          // 送られてこない。書く手間が見合わないため。アプリ内から送れるようにする。
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => FeedbackScreen(
                  service: ServiceLocator.instance.get<FeedbackService>(),
                  userId: userId ?? '',
                  fromScreen: 'help',
                ),
              ),
            ),
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('ご意見・不具合を送る'),
          ),
          const SizedBox(height: 12),
          Text(
            'メールでのご連絡も受け付けています: support@trustcar.jp',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _HelpSectionHeader extends StatelessWidget {
  final String title;
  const _HelpSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// 開閉できるQ&A。初期状態は閉じ、一覧をざっと見渡せるようにする。
class _HelpTile extends StatelessWidget {
  final String question;
  final String answer;

  const _HelpTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          question,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(answer, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _HelpItem {
  final String question;
  final String answer;
  const _HelpItem(this.question, this.answer);
}

class _HelpSection {
  final String title;
  final List<_HelpItem> items;
  const _HelpSection(this.title, this.items);
}

const _sections = <_HelpSection>[
  _HelpSection('はじめに', [
    _HelpItem(
      '最初に何をすればいいですか？',
      'マイカー画面の「車両を登録する」から愛車を登録してください。'
          'メーカー・車種・年式・走行距離だけで始められます。'
          '車検満了日を入れておくと、期限が近づいたときに通知が届きます。',
    ),
    _HelpItem(
      '車検証を撮影するだけで登録できますか？',
      'iPhone / Android アプリでは、車検証をカメラで読み取って自動入力できます。'
          'Web版はカメラ読み取りに対応していないため、フォームから手入力してください。',
    ),
    _HelpItem(
      '複数の車を登録できますか？',
      'できます。フリープランは3台まで、プレミアムプランは台数無制限です。'
          '用途ごとに分けて登録すると、車検期限や整備履歴が車両ごとに管理できます。',
    ),
  ]),
  _HelpSection('整備記録', [
    _HelpItem(
      '整備記録はどう入力しますか？',
      '車両詳細画面の「履歴を追加」から登録します。'
          '整備の種類・日付・費用・工場名・そのときの走行距離を入れておくと、'
          '次回の交換時期の目安が自動で計算されます。',
    ),
    _HelpItem(
      '過去の整備も後から入力できますか？',
      'できます。日付を過去にして登録すれば、時系列の正しい位置に並びます。'
          '手元に整備明細が残っていれば、まとめて入力しておくと売却時の資料になります。',
    ),
    _HelpItem(
      '記録を残すと何の役に立ちますか？',
      '2つあります。1つは次の整備時期の予測精度が上がること。'
          'もう1つは売却・下取り時に「適切に整備されてきた証拠」として提示できることです。'
          '査定額に反映されることがあります。',
    ),
  ]),
  _HelpSection('通知・車検', [
    _HelpItem(
      '車検の通知はいつ届きますか？',
      '車検満了日を登録しておくと、期限が近づいた時点でお知らせします。'
          '通知の種類は 設定 → 通知設定 から個別にオン・オフできます。',
    ),
    _HelpItem(
      '貨物車（4ナンバー）の車検は毎年ですよね？',
      'はい。車両登録時に用途区分を「貨物」にしておくと、'
          '乗用車と異なる車検周期で期限を管理します。',
    ),
    _HelpItem(
      '通知が届きません',
      '端末の設定でアプリの通知が許可されているかご確認ください。'
          'そのうえで、アプリ内の 設定 → 通知設定 で該当の通知がオンになっているかをご確認ください。',
    ),
  ]),
  _HelpSection('整備工場', [
    _HelpItem(
      '工場はどう探せばいいですか？',
      'マーケット画面から、地域・サービス内容・評価で絞り込めます。'
          '位置情報を許可すると近い順に並び替えできます。'
          '気になる工場は最大3件まで並べて比較できます。',
    ),
    _HelpItem(
      '問い合わせるとどうなりますか？',
      'アプリ内のメッセージとして工場に届き、返信もアプリ内で受け取れます。'
          '電話番号やメールアドレスを直接伝える必要はありません。'
          'フリープランは月3件まで、プレミアムプランは無制限です。',
    ),
  ]),
  _HelpSection('プラン・お支払い', [
    _HelpItem(
      'フリープランでどこまで使えますか？',
      '車両3台まで、工場への問い合わせ月3件まで、ドライブログの保存30日間まで'
          'ご利用いただけます。整備記録の登録件数に制限はありません。'
          '詳しい比較は プロフィール →「プラン」からご確認ください。',
    ),
    _HelpItem(
      'プレミアムプランにすると何ができますか？',
      '車両台数・問い合わせ件数・ドライブログ保存が無制限になり、'
          '愛車カルテのPDF出力、整備履歴の工場共有、同車種のコミュニティ傾向、'
          'AIによる整備トレンド分析が使えるようになります。',
    ),
    _HelpItem(
      '解約はどうすればいいですか？',
      'iPhone は App Store、Android は Google Play のサブスクリプション設定から解約します。'
          '解約後も、期間終了までプレミアム機能をご利用いただけます。',
    ),
  ]),
  _HelpSection('データとプライバシー', [
    _HelpItem(
      '車検証の情報は誰かに見られますか？',
      'いいえ。登録した車両情報・整備記録は本人だけが閲覧できます。'
          '整備工場に履歴を共有する場合も、共有するかどうかはご自身で選択できます。',
    ),
    _HelpItem(
      '退会するとデータはどうなりますか？',
      '設定からアカウントを削除すると、車両・整備記録・投稿を含む個人データを削除します。'
          '削除後の復元はできませんのでご注意ください。',
    ),
    _HelpItem(
      '機種変更するとデータは引き継がれますか？',
      '同じアカウントでログインすれば引き継がれます。'
          'データは端末ではなくサーバーに保存されています。',
    ),
  ]),
];
