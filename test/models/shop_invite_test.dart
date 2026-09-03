import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/shop_invite.dart';

/// 店が自分の顧客をアプリに載せるための招待コード。
///
/// 2026-08-27 の再検討（`docs/BUSINESS_MODEL_RETHINK_2026-08-27.md`）で、
/// **これが唯一にして最大の穴**だと分かった。いまの導線はこうなっている。
///
/// ```
///  顧客がアプリを見つける → 自分で入れる → 自分で愛車を登録する
///  → 自分でタカヤモーターを探す → 自分で問い合わせる → やっと店とつながる
/// ```
///
/// **既存客の大半は、この最初の一歩を踏まない。** 車検の入庫時に
/// 「次回のご案内はこちらから」と紙やQRで渡せる形にする。
///
/// コードは**人が読んで手で入力できること**が要件。カウンターで口頭で伝える
/// 場面があるため、見間違える文字（0/O・1/I/L）を最初から除く。
void main() {
  group('InviteCode.generate', () {
    test('既定の長さで作られる', () {
      final code = InviteCode.generate(seed: 1);

      expect(code.length, InviteCode.length);
    });

    test('紛らわしい文字を含まない', () {
      // 0/O、1/I/L は電話や口頭で伝えるときに必ず間違われる。
      for (var seed = 0; seed < 200; seed++) {
        final code = InviteCode.generate(seed: seed);
        for (final banned in ['0', 'O', '1', 'I', 'L']) {
          expect(code.contains(banned), isFalse, reason: '$code に $banned');
        }
      }
    });

    test('同じ種からは同じコードが出る（テストで固定できる）', () {
      expect(InviteCode.generate(seed: 42), InviteCode.generate(seed: 42));
    });

    test('違う種からは違うコードが出る', () {
      final codes = {
        for (var i = 0; i < 200; i++) InviteCode.generate(seed: i)
      };

      // 完全な重複ゼロは保証できないが、大半は散る。
      expect(codes.length, greaterThan(190));
    });

    test('英大文字と数字だけでできている', () {
      final code = InviteCode.generate(seed: 7);
      expect(RegExp(r'^[A-Z0-9]+$').hasMatch(code), isTrue);
    });
  });

  group('InviteCode.normalize', () {
    test('小文字は大文字にする', () {
      expect(InviteCode.normalize('abc234'), 'ABC234');
    });

    test('空白とハイフンは落とす', () {
      // 「ABC-234」「ABC 234」と書いて渡すことがある。
      expect(InviteCode.normalize('ABC-234'), 'ABC234');
      expect(InviteCode.normalize(' ABC 234 '), 'ABC234');
    });

    test('見間違えやすい文字は寄せる', () {
      // 顧客が 0 と書いても O のつもりのことがある。コードに O は含まれない
      // ので、0 → O ではなく、**含まれない文字のほうを含まれる文字に寄せる**。
      expect(InviteCode.normalize('O2345B'), 'O2345B'.replaceAll('O', '0'));
      expect(InviteCode.normalize('I2345B'), 'I2345B'.replaceAll('I', '1'));
      expect(InviteCode.normalize('L2345B'), 'L2345B'.replaceAll('L', '1'));
    });

    group('Edge Cases', () {
      test('空文字は空文字のまま', () {
        expect(InviteCode.normalize(''), '');
      });

      test('全角の英数字も受け付ける', () {
        // スマホの入力で全角になることがある。ここで弾くと問い合わせになる。
        expect(InviteCode.normalize('ＡＢＣ２３４'), 'ABC234');
      });

      test('記号が混ざっても落とす', () {
        expect(InviteCode.normalize('AB#C2/34'), 'ABC234');
      });
    });
  });

  group('ShopInvite.canBeUsedBy', () {
    ShopInvite invite({
      bool isActive = true,
      DateTime? expiresAt,
      int usedCount = 0,
      int? maxUses,
      String shopOwnerId = 'owner-1',
    }) {
      return ShopInvite(
        code: 'ABC234',
        shopId: 'shop-1',
        shopName: 'タカヤモーター',
        shopOwnerId: shopOwnerId,
        createdAt: DateTime(2026, 8, 1),
        expiresAt: expiresAt,
        isActive: isActive,
        usedCount: usedCount,
        maxUses: maxUses,
      );
    }

    final now = DateTime(2026, 8, 27);

    test('通常は使える', () {
      expect(invite().canBeUsedBy('user-1', now: now), isNull);
    });

    test('止められた招待は使えない', () {
      expect(
        invite(isActive: false).canBeUsedBy('user-1', now: now),
        InviteRejection.inactive,
      );
    });

    test('期限切れは使えない', () {
      expect(
        invite(expiresAt: DateTime(2026, 8, 20))
            .canBeUsedBy('user-1', now: now),
        InviteRejection.expired,
      );
    });

    test('上限に達したら使えない', () {
      expect(
        invite(usedCount: 50, maxUses: 50).canBeUsedBy('user-1', now: now),
        InviteRejection.exhausted,
      );
    });

    test('店主が自分の招待を使うことはできない', () {
      // 自分で自分の顧客になると、店側の顧客数が狂う。
      expect(
        invite(shopOwnerId: 'user-1').canBeUsedBy('user-1', now: now),
        InviteRejection.selfInvite,
      );
    });

    group('Edge Cases', () {
      test('期限が無ければ切れない', () {
        expect(invite(expiresAt: null).canBeUsedBy('user-1', now: now), isNull);
      });

      test('上限が無ければ何人でも使える', () {
        expect(
          invite(usedCount: 9999, maxUses: null)
              .canBeUsedBy('user-1', now: now),
          isNull,
        );
      });

      test('期限ちょうどはまだ使える', () {
        expect(
          invite(expiresAt: now).canBeUsedBy('user-1', now: now),
          isNull,
        );
      });

      test('上限の1つ手前なら使える', () {
        expect(
          invite(usedCount: 49, maxUses: 50).canBeUsedBy('user-1', now: now),
          isNull,
        );
      });

      test('利用者IDが空なら使えない', () {
        expect(
          invite().canBeUsedBy('', now: now),
          InviteRejection.notSignedIn,
        );
      });

      test('止まっていて期限も切れていたら、止まっている方を先に言う', () {
        // 店主が止めたのなら「期限切れ」と案内するのは誤り。
        expect(
          invite(isActive: false, expiresAt: DateTime(2026, 8, 1))
              .canBeUsedBy('user-1', now: now),
          InviteRejection.inactive,
        );
      });
    });
  });

  group('InviteRejection の文言', () {
    test('すべての理由に、利用者向けの説明がある', () {
      for (final r in InviteRejection.values) {
        expect(r.message.isNotEmpty, isTrue, reason: r.name);
      }
    });

    test('文言に開発者向けの用語が出てこない', () {
      for (final r in InviteRejection.values) {
        for (final ng in ['null', 'error', 'invalid', 'Exception']) {
          expect(r.message.contains(ng), isFalse, reason: '${r.name}: $ng');
        }
      }
    });
  });

  group('ShopInvite の保存と復元', () {
    test('保存して読み戻すと同じになる', () {
      final original = ShopInvite(
        code: 'ABC234',
        shopId: 'shop-1',
        shopName: 'タカヤモーター',
        shopOwnerId: 'owner-1',
        createdAt: DateTime(2026, 8, 1),
        expiresAt: DateTime(2026, 12, 31),
        isActive: true,
        usedCount: 3,
        maxUses: 100,
      );

      final restored = ShopInvite.fromMap(original.toMap(), original.code);

      expect(restored.shopId, original.shopId);
      expect(restored.shopName, original.shopName);
      expect(restored.shopOwnerId, original.shopOwnerId);
      expect(restored.isActive, original.isActive);
      expect(restored.usedCount, original.usedCount);
      expect(restored.maxUses, original.maxUses);
      expect(restored.expiresAt, original.expiresAt);
    });

    group('Edge Cases', () {
      test('欠けた項目があっても落ちない', () {
        final restored = ShopInvite.fromMap(const {}, 'ABC234');

        expect(restored.code, 'ABC234');
        expect(restored.shopId, '');
        expect(restored.isActive, isFalse);
        expect(restored.usedCount, 0);
      });

      test('項目が欠けた招待は使えない（既定で止まっている扱い）', () {
        final restored = ShopInvite.fromMap(const {}, 'ABC234');

        expect(
          restored.canBeUsedBy('user-1', now: DateTime(2026, 8, 27)),
          InviteRejection.inactive,
        );
      });
    });
  });
}
