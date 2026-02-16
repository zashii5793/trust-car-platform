import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/inquiry.dart';

void main() {
  group('InquiryStatus', () {
    test('fromString returns correct enum value', () {
      expect(InquiryStatus.fromString('pending'), InquiryStatus.pending);
      expect(InquiryStatus.fromString('inProgress'), InquiryStatus.inProgress);
      expect(InquiryStatus.fromString('replied'), InquiryStatus.replied);
      expect(InquiryStatus.fromString('closed'), InquiryStatus.closed);
      expect(InquiryStatus.fromString('cancelled'), InquiryStatus.cancelled);
    });

    test('fromString returns null for invalid value', () {
      expect(InquiryStatus.fromString('invalid'), isNull);
      expect(InquiryStatus.fromString(null), isNull);
    });

    test('displayName returns Japanese name', () {
      expect(InquiryStatus.pending.displayName, '未対応');
      expect(InquiryStatus.inProgress.displayName, '対応中');
      expect(InquiryStatus.replied.displayName, '回答済み');
      expect(InquiryStatus.closed.displayName, 'クローズ');
      expect(InquiryStatus.cancelled.displayName, 'キャンセル');
    });
  });

  group('InquiryType', () {
    test('fromString returns correct enum value', () {
      expect(InquiryType.fromString('partInquiry'), InquiryType.partInquiry);
      expect(InquiryType.fromString('serviceInquiry'), InquiryType.serviceInquiry);
      expect(InquiryType.fromString('estimate'), InquiryType.estimate);
      expect(InquiryType.fromString('appointment'), InquiryType.appointment);
    });

    test('fromString returns null for invalid value', () {
      expect(InquiryType.fromString('invalid'), isNull);
      expect(InquiryType.fromString(null), isNull);
    });

    test('displayName returns Japanese name', () {
      expect(InquiryType.partInquiry.displayName, 'パーツについて');
      expect(InquiryType.estimate.displayName, '見積もり依頼');
      expect(InquiryType.appointment.displayName, '予約・来店');
      expect(InquiryType.general.displayName, 'その他');
    });
  });

  group('InquiryMessage', () {
    test('creates with required fields', () {
      final message = InquiryMessage(
        id: 'msg1',
        senderId: 'user1',
        isFromShop: false,
        content: 'テストメッセージ',
        sentAt: DateTime(2024, 1, 1, 10, 0),
      );

      expect(message.id, 'msg1');
      expect(message.senderId, 'user1');
      expect(message.isFromShop, false);
      expect(message.content, 'テストメッセージ');
      expect(message.isRead, false);
      expect(message.attachmentUrls, isEmpty);
    });

    test('fromMap creates from map', () {
      final message = InquiryMessage.fromMap({
        'senderId': 'shop1',
        'isFromShop': true,
        'content': '店舗からの返信',
        'attachmentUrls': ['url1', 'url2'],
        'isRead': true,
      }, 'msg2');

      expect(message.id, 'msg2');
      expect(message.senderId, 'shop1');
      expect(message.isFromShop, true);
      expect(message.content, '店舗からの返信');
      expect(message.attachmentUrls, ['url1', 'url2']);
      expect(message.isRead, true);
    });

    test('toMap converts to map', () {
      final message = InquiryMessage(
        id: 'msg1',
        senderId: 'user1',
        isFromShop: false,
        content: 'テストメッセージ',
        attachmentUrls: ['url1'],
        sentAt: DateTime(2024, 1, 1, 10, 0),
        isRead: true,
      );

      final map = message.toMap();

      expect(map['senderId'], 'user1');
      expect(map['isFromShop'], false);
      expect(map['content'], 'テストメッセージ');
      expect(map['attachmentUrls'], ['url1']);
      expect(map['isRead'], true);
    });
  });

  group('Inquiry', () {
    late Inquiry inquiry;

    setUp(() {
      inquiry = Inquiry(
        id: 'inq1',
        userId: 'user1',
        shopId: 'shop1',
        type: InquiryType.estimate,
        status: InquiryStatus.pending,
        subject: '車検見積もりについて',
        initialMessage: 'スバル レガシィの車検見積もりをお願いします。',
        vehicleMaker: 'スバル',
        vehicleModel: 'レガシィ',
        vehicleYear: 2020,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        messageCount: 1,
        unreadCountUser: 0,
        unreadCountShop: 1,
      );
    });

    test('hasReply returns false when not replied', () {
      expect(inquiry.hasReply, false);
    });

    test('hasReply returns true when replied', () {
      final replied = inquiry.copyWith(
        repliedAt: DateTime(2024, 1, 2),
      );

      expect(replied.hasReply, true);
    });

    test('isOpen returns true for pending status', () {
      expect(inquiry.isOpen, true);
    });

    test('isOpen returns true for inProgress status', () {
      final inProgress = inquiry.copyWith(status: InquiryStatus.inProgress);
      expect(inProgress.isOpen, true);
    });

    test('isOpen returns false for closed status', () {
      final closed = inquiry.copyWith(status: InquiryStatus.closed);
      expect(closed.isOpen, false);
    });

    test('isOpen returns false for cancelled status', () {
      final cancelled = inquiry.copyWith(status: InquiryStatus.cancelled);
      expect(cancelled.isOpen, false);
    });

    test('displayStatus shows 返信待ち for pending', () {
      expect(inquiry.displayStatus, '返信待ち');
    });

    test('displayStatus shows status name for other statuses', () {
      final replied = inquiry.copyWith(status: InquiryStatus.replied);
      expect(replied.displayStatus, '回答済み');
    });

    test('vehicleDisplay combines maker, model and year', () {
      expect(inquiry.vehicleDisplay, 'スバル レガシィ (2020年式)');
    });

    test('vehicleDisplay returns null when no maker', () {
      final noVehicle = inquiry.copyWith(vehicleMaker: null);
      // Note: copyWith doesn't allow setting to null, so we create a new inquiry
      final noVehicleInquiry = Inquiry(
        id: 'inq2',
        userId: 'user1',
        shopId: 'shop1',
        type: InquiryType.general,
        subject: 'テスト',
        initialMessage: 'テスト',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(noVehicleInquiry.vehicleDisplay, isNull);
    });

    test('toMap converts to map correctly', () {
      final map = inquiry.toMap();

      expect(map['userId'], 'user1');
      expect(map['shopId'], 'shop1');
      expect(map['type'], 'estimate');
      expect(map['status'], 'pending');
      expect(map['subject'], '車検見積もりについて');
      expect(map['vehicleMaker'], 'スバル');
      expect(map['vehicleModel'], 'レガシィ');
      expect(map['vehicleYear'], 2020);
      expect(map['messageCount'], 1);
      expect(map['unreadCountUser'], 0);
      expect(map['unreadCountShop'], 1);
    });

    test('copyWith creates modified copy', () {
      final modified = inquiry.copyWith(
        status: InquiryStatus.replied,
        messageCount: 3,
      );

      expect(modified.status, InquiryStatus.replied);
      expect(modified.messageCount, 3);
      expect(modified.userId, inquiry.userId);
      expect(modified.subject, inquiry.subject);
    });

    test('equality is based on id', () {
      final inquiry2 = inquiry.copyWith(subject: '別の件名');

      expect(inquiry == inquiry2, true);
      expect(inquiry.hashCode, inquiry2.hashCode);
    });

    test('toString returns readable format', () {
      expect(inquiry.toString(), 'Inquiry(車検見積もりについて, 未対応)');
    });
  });
}
