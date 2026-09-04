import 'package:flutter/material.dart';
import '../../core/constants/spacing.dart';

/// プライバシーポリシー画面
///
/// App Store / Google Play 審査で必須の法的ドキュメント。
/// 収集データ・利用目的・第三者提供・開示請求先を記載。
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('プライバシーポリシー'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingScreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'プライバシーポリシー',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '最終更新日: 2026年9月3日（ドラフトです。特定商取引法に基づく表示の未記入欄を埋め、専門家確認を経てから公開してください）',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            _PolicySection(
              title: '1. はじめに',
              content: 'TrustCar（以下「当サービス」）は、ユーザーのプライバシーを尊重し、個人情報の保護に努めます。'
                  '本プライバシーポリシーは、当サービスが収集する情報、その利用方法、および保護措置について説明します。',
            ),
            _PolicySection(
              title: '2. 収集する情報',
              content: '当サービスは以下の情報を収集します。\n\n'
                  '【アカウント情報】\n'
                  '・メールアドレス\n'
                  '・パスワード（暗号化して保存）\n'
                  '・Googleアカウント情報（Googleログインご利用時）\n'
                  '・表示名・プロフィール写真\n\n'
                  '【車両情報】\n'
                  '・車種・年式・走行距離\n'
                  '・車体番号・ナンバープレート（任意）\n'
                  '・車両の写真\n\n'
                  '【整備記録】\n'
                  '・整備日時・内容・費用\n'
                  '・整備写真・請求書画像（請求書OCR機能を利用した場合、整備工場等の店舗名・住所・電話番号を含むことがあります）\n\n'
                  '【位置情報（ドライブログ機能）】\n'
                  '・GPSによる走行経路\n'
                  '・走行距離・所要時間・燃費\n'
                  '・立ち寄りスポット情報\n'
                  '※ 位置情報はドライブログ機能使用中のみ収集します。\n\n'
                  '【コミュニティ情報】\n'
                  '・投稿内容・コメント・いいね\n'
                  '・フォロー・フォロワー関係\n\n'
                  '【AIチャット】\n'
                  '・AIチャット機能で入力したメッセージ・車両情報（第三者の生成AIサービスへ送信されます。4章参照）\n\n'
                  '【利用状況】\n'
                  '・アプリの利用状況・クラッシュレポート（Firebase Analytics/Crashlytics）\n'
                  '・デバイス情報（OS種別・バージョン）',
            ),
            _PolicySection(
              title: '3. 情報の利用目的',
              content: '収集した情報は以下の目的で利用します。\n\n'
                  '・サービスの提供・維持・改善\n'
                  '・ユーザー認証・アカウント管理\n'
                  '・整備記録・ドライブログの管理・表示\n'
                  '・法人契約者による社用車の一括管理（fleet機能。6章参照）\n'
                  '・ユーザー間のパーツ売買の仲介（7章参照）\n'
                  '・車両に関するリマインダー・通知の送信\n'
                  '・コミュニティ機能（SNS投稿・フォロー）の提供\n'
                  '・お問い合わせへの対応\n'
                  '・不正利用の検知・防止\n'
                  '・法令上の義務の履行',
            ),
            _PolicySection(
              title: '4. 情報の第三者提供・委託',
              content: '当サービスは、以下の場合を除き、ユーザーの個人情報を第三者に提供しません。\n\n'
                  '・ユーザーの同意がある場合\n'
                  '・法令に基づく場合\n'
                  '・人の生命・身体・財産の保護のために必要な場合\n'
                  '・公衆衛生の向上・児童の健全育成のために必要な場合\n\n'
                  '【業務委託先】\n'
                  '・Google Firebase（認証・データベース・ストレージ・分析・クラッシュレポート）\n'
                  '・Google Maps Platform（近隣の整備工場等の地図表示。位置情報を送信します）\n'
                  '・Anthropic（AIチャット機能。ユーザーの入力内容・車両情報を送信します。'
                  '当サービスのサーバーを経由して送信し、Anthropicへ当サービスのAPIキーは開示されません）\n'
                  '・SendGrid（メールマガジン・お知らせメールの配信）\n'
                  '・App Store / Google Play（アプリ内課金の決済処理）、RevenueCat（課金状況の管理）\n\n'
                  'これらの委託先における取扱いについては、各社のプライバシーポリシーもご確認ください。',
            ),
            _PolicySection(
              title: '5. 位置情報について',
              content: '当サービスはドライブログ機能において位置情報を利用します。\n\n'
                  '・記録中にアプリを利用している間のみ取得します。'
                  'バックグラウンドでの取得は行いません\n'
                  '・ドライブログは初期設定では非公開で、ご本人のみが閲覧できます\n'
                  '・お客様が明示的に公開設定を選択したドライブログに限り、'
                  '他のユーザーに公開されます\n'
                  '・公開する場合、経路の始点・終点から半径500m以内を除去し、'
                  '住所は市区町村までに丸めます\n'
                  '・この処理は完全な匿名化を保証するものではありません。'
                  '複数の公開ログを組み合わせると行動範囲が推測される可能性があります\n'
                  '・公開を取り消しても、公開中に第三者が保存した情報の削除は'
                  '保証できません\n'
                  '・近隣の整備工場の地図表示のため Google Maps に送信します\n'
                  '・位置情報の収集はアプリ設定から無効にできます\n'
                  '・デバイスのOS設定から位置情報の利用許可を変更できます',
            ),
            _PolicySection(
              title: '6. 法人（fleet）機能における情報の取扱い',
              content: '法人その他の団体（以下「契約法人」）が社用車を一括管理する fleet 機能をご利用の場合、'
                  '以下の取扱いとなります。\n\n'
                  '・契約法人の管理者・マネージャー権限を持つメンバーは、fleet機能を通じて、'
                  '当該契約法人に所属するメンバーの車両情報・整備記録・走行データ等を閲覧できます\n'
                  '・契約法人は、メンバーの情報をTrustCarを通じて管理することについて、メンバーから'
                  '必要な同意を得るか、メンバーに対し必要な通知を行うものとします\n'
                  '・fleet機能における契約法人と当サービスの役割分担（個人情報保護法上の整理）は、'
                  '契約法人との間で別途締結する法人向け契約において定めます',
            ),
            _PolicySection(
              title: '7. パーツ等のユーザー間取引における情報の取扱い',
              content: 'ユーザー間の中古パーツ等の売買（C2C取引）を仲介する機能において、以下の情報を取扱います。\n\n'
                  '・出品情報（商品名・状態・価格・出品者への支払額・画像等）\n'
                  '・取引成立後、発送・受取のために必要な範囲で、出品者・購入者間または当サービスと'
                  '配送事業者との間で氏名・送付先住所等を共有する場合があります\n'
                  '・取引に関する手数料の計算・支払のため、決済・振込に必要な情報を取扱います',
            ),
            _PolicySection(
              title: '8. データの保存・セキュリティ',
              content: '・データはGoogle Cloud（Firebase）のサーバーに保存されます\n'
                  '・通信はSSL/TLSにより暗号化されます\n'
                  '・パスワードは暗号化して保存され、平文では保存しません\n'
                  '・不正アクセス防止のためのセキュリティ対策を実施しています\n'
                  '・ただし、インターネット上での完全なセキュリティを保証するものではありません',
            ),
            _PolicySection(
              title: '9. データの保持期間',
              content: '・アカウント情報・車両情報・整備記録・投稿・コメント・'
                  'ドライブログ・位置情報：退会手続きの完了時に削除します\n'
                  '  （削除処理は毎日実行されるため、実際に消去されるのは退会後、'
                  '最初の処理が動いたときです。通常は翌日までに完了します）\n'
                  '・バックアップデータ：障害復旧のための日次バックアップに、'
                  '上記の削除後さらに最大30日間残り、その後自動的に消去されます\n'
                  '・退会後の復旧はできません。猶予期間を設けていないため、'
                  '誤って退会された場合もデータを元に戻すことはできません\n\n'
                  'ユーザー間のパーツ売買（C2C取引）の機能は、現在停止しています。'
                  '再開する場合は、取引記録について法令（税法・電子帳簿保存法等）に基づく'
                  '保存期間を定めたうえで、本ポリシーを改定してお知らせします。',
            ),
            _PolicySection(
              title: '10. ユーザーの権利',
              content: 'ユーザーは以下の権利を有します。\n\n'
                  '・個人情報の開示請求\n'
                  '・個人情報の訂正・追加・削除の請求\n'
                  '・個人情報の利用停止・消去の請求\n'
                  '・第三者提供の停止の請求\n\n'
                  'これらの請求はアプリ内のお問い合わせ機能、または下記の連絡先までご連絡ください。',
            ),
            _PolicySection(
              title: '11. 未成年者の利用',
              content: '当サービスは13歳未満のお子様のご利用を想定していません。'
                  '13歳未満のお子様が個人情報を提供していると判明した場合、速やかに当該情報を削除します。',
            ),
            _PolicySection(
              title: '12. プライバシーポリシーの変更',
              content: '当サービスは、法令の変更やサービスの改善に伴い、本ポリシーを変更することがあります。'
                  '重要な変更がある場合は、アプリ内での通知またはメールでお知らせします。'
                  '変更にご同意いただけない場合、ユーザーは適用日より前に退会することができます。',
            ),
            _PolicySection(
              title: '13. 運営者',
              content: 'ZAXEL合同会社\n\n'
                  '代表者名・所在地・電話番号は「特定商取引法に基づく表示」に記載しています。',
            ),
            _PolicySection(
              title: '14. お問い合わせ',
              content: '個人情報の取り扱いに関するお問い合わせは下記までご連絡ください。\n\n'
                  'TrustCar サポートチーム\n'
                  'メールアドレス: support@trustcar.jp\n'
                  '受付時間: 平日 10:00〜18:00（土日祝日・年末年始を除く）',
            ),
            const SizedBox(height: 32),
            Text(
              '© 2026 TrustCar, operated by ZAXEL合同会社. All rights reserved.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String content;

  const _PolicySection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
