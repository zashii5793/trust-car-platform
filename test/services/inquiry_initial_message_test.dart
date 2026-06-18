import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/services/shop_subscription_service.dart';

/// createInquiry が「初回メッセージ」をスレッド(messages サブコレクション)へ
/// 書き込むことを検証する。これがないと送信直後にスレッドを開いても
/// 「メッセージはまだありません」と表示され、ユーザーが不安になる。
void main() {
  group('InquiryService.createInquiry 初回メッセージ', () {
    late FakeFirebaseFirestore fs;
    late InquiryService service;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      // フリープラン・有効状態の店舗を用意（問い合わせ受付可能にする）
      await fs.collection('shops').doc('shop1').set({
        'planType': 'free',
        'subscriptionStatus': 'active',
      });
      service = InquiryService(
        firestore: fs,
        subscriptionService: ShopSubscriptionService(firestore: fs),
      );
    });

    test('作成直後にスレッドへ初回メッセージが書き込まれる', () async {
      final result = await service.createInquiry(
        userId: 'u1',
        shopId: 'shop1',
        type: InquiryType.estimate,
        subject: '見積もり',
        message: '車検の見積もりをお願いします',
      );
      expect(result.isSuccess, true);

      final messages = await service.getMessages(result.valueOrNull!.id);
      expect(messages.isSuccess, true);
      expect(messages.valueOrNull, hasLength(1));
      expect(messages.valueOrNull!.first.content, '車検の見積もりをお願いします');
      expect(messages.valueOrNull!.first.isFromShop, false);
      // 送信者本人の初回メッセージは既読扱い
      expect(messages.valueOrNull!.first.isRead, true);
    });

    test('添付画像が初回メッセージに引き継がれる', () async {
      final result = await service.createInquiry(
        userId: 'u1',
        shopId: 'shop1',
        type: InquiryType.estimate,
        subject: '異音の見積もり',
        message: '異音がします',
        attachmentUrls: const ['https://example.com/a.jpg'],
      );
      expect(result.isSuccess, true);

      final messages = await service.getMessages(result.valueOrNull!.id);
      expect(
        messages.valueOrNull!.first.attachmentUrls,
        contains('https://example.com/a.jpg'),
      );
    });

    test('messageCount は初回メッセージ分の 1 で整合する', () async {
      final result = await service.createInquiry(
        userId: 'u1',
        shopId: 'shop1',
        type: InquiryType.general,
        subject: '質問',
        message: '営業時間を教えてください',
      );
      expect(result.valueOrNull!.messageCount, 1);
    });
  });
}
