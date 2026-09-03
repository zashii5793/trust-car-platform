import 'package:cloud_firestore/cloud_firestore.dart';

/// A code a shop hands to its own customers.
///
/// 2026-08-27 の再検討（`docs/BUSINESS_MODEL_RETHINK_2026-08-27.md`）で、
/// **店が自分の顧客をアプリに載せる手段が無い**ことが最大の穴だと分かった。
/// いまの導線は「顧客がアプリを見つけ、自分で入れ、自分で店を探し、自分で
/// 問い合わせる」で、既存客の大半は最初の一歩を踏まない。
///
/// 車検の入庫時に「次回のご案内はこちらから」と紙やQRで渡せる形にする。
class ShopInvite {
  final String code;
  final String shopId;
  final String shopName;

  /// 店主のユーザーID。自分で自分の招待を使えないようにするために持つ。
  final String shopOwnerId;

  final DateTime createdAt;

  /// 期限。null なら切れない。
  final DateTime? expiresAt;

  final bool isActive;
  final int usedCount;

  /// 使える上限。null なら無制限（カウンターに置くQR向け）。
  final int? maxUses;

  const ShopInvite({
    required this.code,
    required this.shopId,
    required this.shopName,
    required this.shopOwnerId,
    required this.createdAt,
    required this.isActive,
    required this.usedCount,
    this.expiresAt,
    this.maxUses,
  });

  /// [userId] がこの招待を使えるか。使えるなら null、使えないなら理由を返す。
  ///
  /// 判定の順番に意味がある。**店主が止めた招待を「期限切れです」と案内する
  /// のは誤り**なので、止まっているかを先に見る。
  InviteRejection? canBeUsedBy(String userId, {required DateTime now}) {
    if (userId.trim().isEmpty) return InviteRejection.notSignedIn;
    if (!isActive) return InviteRejection.inactive;

    final until = expiresAt;
    // 期限ちょうどはまだ使える。「今日まで有効」と書いて配るため。
    if (until != null && now.isAfter(until)) return InviteRejection.expired;

    final limit = maxUses;
    if (limit != null && usedCount >= limit) return InviteRejection.exhausted;

    if (userId == shopOwnerId) return InviteRejection.selfInvite;

    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'shopName': shopName,
      'shopOwnerId': shopOwnerId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      'isActive': isActive,
      'usedCount': usedCount,
      if (maxUses != null) 'maxUses': maxUses,
    };
  }

  /// 欠けた項目があっても落とさない。
  ///
  /// ただし **`isActive` の既定は false**。読めなかった招待を「使える」と
  /// 判断すると、誰の顧客か分からないまま紐づいてしまう。
  factory ShopInvite.fromMap(Map<String, dynamic> map, String code) {
    DateTime? asDate(Object? v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return ShopInvite(
      code: code,
      shopId: map['shopId'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      shopOwnerId: map['shopOwnerId'] as String? ?? '',
      createdAt:
          asDate(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt: asDate(map['expiresAt']),
      isActive: map['isActive'] as bool? ?? false,
      usedCount: (map['usedCount'] as num?)?.toInt() ?? 0,
      maxUses: (map['maxUses'] as num?)?.toInt(),
    );
  }
}

/// なぜ招待が使えないか。**利用者にそのまま見せる文言**を持つ。
enum InviteRejection {
  notSignedIn('コードを使うにはログインが必要です'),
  inactive('このコードは使えなくなっています。お店にお問い合わせください'),
  expired('このコードは期限が切れています。お店にお問い合わせください'),
  exhausted('このコードは上限に達しました。お店にお問い合わせください'),
  selfInvite('ご自身のお店のコードは使えません'),
  notFound('コードが見つかりません。入力をお確かめください');

  final String message;
  const InviteRejection(this.message);
}

/// 招待コードの作り方と読み方。
///
/// **人が読んで手で入力できること**が要件。カウンターで口頭で伝える場面が
/// あるので、見間違える文字は最初から使わない。
class InviteCode {
  InviteCode._();

  static const int length = 6;

  /// 使う文字。**0/O・1/I/L を除いてある。**
  /// 電話や口頭で伝えると必ず間違われるため。
  static const String _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

  /// コードを作る。[seed] を渡すとテストから固定できる。
  static String generate({required int seed}) {
    // 線形合同法。暗号用途ではない（招待コードは総当たりされても、
    // 紐づく先は「その店の顧客になる」だけで、データは読めない）。
    var state = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
      buffer.write(_alphabet[(state >> 8) % _alphabet.length]);
    }
    return buffer.toString();
  }

  /// 入力されたコードを、照合できる形に直す。
  ///
  /// 紙に「ABC-234」と書いて渡したり、スマホで全角になったりする。
  /// **ここで弾くと、店への問い合わせになる。** 直せるものは直す。
  static String normalize(String input) {
    final buffer = StringBuffer();

    for (final rune in input.runes) {
      var c = rune;

      // 全角英数字を半角へ（Ａ-Ｚ / ａ-ｚ / ０-９）
      if (c >= 0xFF21 && c <= 0xFF3A) c -= 0xFEE0; // Ａ-Ｚ
      if (c >= 0xFF41 && c <= 0xFF5A) c -= 0xFEE0; // ａ-ｚ
      if (c >= 0xFF10 && c <= 0xFF19) c -= 0xFEE0; // ０-９

      var ch = String.fromCharCode(c).toUpperCase();

      // 使わない文字が入力されたら、似ている使う文字へ寄せる。
      // コードに O は無いので、O と書かれたら 0 のつもり…ではなく、
      // **0 は使う文字なので O → 0 に寄せる**（逆向きにすると当たらない）。
      switch (ch) {
        case 'O':
          ch = '0';
          break;
        case 'I':
        case 'L':
          ch = '1';
          break;
      }

      if (RegExp(r'[A-Z0-9]').hasMatch(ch)) buffer.write(ch);
    }

    return buffer.toString();
  }
}
