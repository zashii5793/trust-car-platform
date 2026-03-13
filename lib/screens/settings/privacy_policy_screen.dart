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
              '最終更新日: 2026年4月1日',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),

            _PolicySection(
              title: '1. はじめに',
              content:
                  'TrustCar（以下「当サービス」）は、ユーザーのプライバシーを尊重し、個人情報の保護に努めます。'
                  '本プライバシーポリシーは、当サービスが収集する情報、その利用方法、および保護措置について説明します。'
                  '\n\n当サービスをご利用いただくことで、本ポリシーに同意したものとみなします。',
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
                  '・整備写真・領収書画像\n\n'
                  '【位置情報（ドライブログ機能）】\n'
                  '・GPSによる走行経路\n'
                  '・走行距離・所要時間・燃費\n'
                  '・立ち寄りスポット情報\n'
                  '※ 位置情報はドライブログ機能使用中のみ収集します。\n\n'
                  '【コミュニティ情報】\n'
                  '・投稿内容・コメント・いいね\n'
                  '・フォロー・フォロワー関係\n\n'
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
                  '・車両に関するリマインダー・通知の送信\n'
                  '・BtoBマーケットプレイスでの工場・パーツ検索\n'
                  '・コミュニティ機能（SNS投稿・フォロー）の提供\n'
                  '・お問い合わせへの対応\n'
                  '・不正利用の検知・防止\n'
                  '・法令上の義務の履行',
            ),

            _PolicySection(
              title: '4. 情報の第三者提供',
              content: '当サービスは、以下の場合を除き、ユーザーの個人情報を第三者に提供しません。\n\n'
                  '・ユーザーの同意がある場合\n'
                  '・法令に基づく場合\n'
                  '・人の生命・身体・財産の保護のために必要な場合\n'
                  '・公衆衛生の向上・児童の健全育成のために必要な場合\n\n'
                  '【利用するサービス（委託先）】\n'
                  '・Google Firebase（認証・データベース・分析）\n'
                  '・Google Analytics（利用状況分析）\n'
                  '・Firebase Crashlytics（クラッシュレポート）\n\n'
                  'これらのサービスのプライバシーポリシーについては各社のポリシーをご確認ください。',
            ),

            _PolicySection(
              title: '5. 位置情報について',
              content: '当サービスはドライブログ機能において位置情報を利用します。\n\n'
                  '・位置情報はドライブ記録の作成時のみ収集します\n'
                  '・収集した位置情報は当該ユーザー本人のみが閲覧できます\n'
                  '・公開設定にしたドライブログは他のユーザーが閲覧できます\n'
                  '・位置情報の収集はアプリ設定から無効にできます\n'
                  '・デバイスのOS設定から位置情報の利用許可を変更できます',
            ),

            _PolicySection(
              title: '6. データの保存・セキュリティ',
              content: '・データはGoogle Cloud（Firebase）のサーバーに保存されます\n'
                  '・通信はSSL/TLSにより暗号化されます\n'
                  '・パスワードは暗号化して保存され、平文では保存しません\n'
                  '・不正アクセス防止のためのセキュリティ対策を実施しています\n'
                  '・ただし、インターネット上での完全なセキュリティを保証するものではありません',
            ),

            _PolicySection(
              title: '7. データの保持期間',
              content: '・アカウント情報：退会後30日間保持後、削除\n'
                  '・車両情報・整備記録：退会後30日間保持後、削除\n'
                  '・投稿・コメント：退会後30日間保持後、削除\n'
                  '・ドライブログ・位置情報：退会後30日間保持後、削除\n'
                  '・バックアップデータ：最大90日間保持後、削除',
            ),

            _PolicySection(
              title: '8. ユーザーの権利',
              content: 'ユーザーは以下の権利を有します。\n\n'
                  '・個人情報の開示請求\n'
                  '・個人情報の訂正・追加・削除の請求\n'
                  '・個人情報の利用停止・消去の請求\n'
                  '・第三者提供の停止の請求\n\n'
                  'これらの請求はアプリ内のお問い合わせ機能、または下記の連絡先までご連絡ください。',
            ),

            _PolicySection(
              title: '9. 未成年者の利用',
              content: '当サービスは13歳未満のお子様のご利用を想定していません。'
                  '13歳未満のお子様が個人情報を提供していると判明した場合、速やかに当該情報を削除します。',
            ),

            _PolicySection(
              title: '10. プライバシーポリシーの変更',
              content: '当サービスは、法令の変更やサービスの改善に伴い、本ポリシーを変更することがあります。'
                  '重要な変更がある場合は、アプリ内での通知またはメールでお知らせします。'
                  '変更後も継続してサービスを利用された場合、変更後のポリシーに同意したものとみなします。',
            ),

            _PolicySection(
              title: '11. お問い合わせ',
              content: '個人情報の取り扱いに関するお問い合わせは下記までご連絡ください。\n\n'
                  'TrustCar サポートチーム\n'
                  'メールアドレス: support@trustcar.jp\n'
                  '受付時間: 平日 10:00〜18:00（土日祝日・年末年始を除く）',
            ),

            const SizedBox(height: 32),
            Text(
              '© 2026 TrustCar. All rights reserved.',
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
