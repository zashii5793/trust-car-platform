import '../../models/drive_log.dart';

/// 公開ドライブログから自宅を割り出せないようにする処理。
///
/// ドライブの経路は、たいてい自宅から始まって自宅で終わる。そのまま公開
/// すると **住所を書いていなくても自宅が特定できる**。共有機能を付ける以上、
/// ここを曖昧にするのは後回しにできない。
///
/// 方針は2つ。
/// 1. 経路の始点・終点から一定半径内の点を丸ごと落とす（[blurRouteEnds]）
/// 2. 住所を市区町村までに切り詰める（[coarsenAddress]）
///
/// 半径を大きくしすぎると経路がほとんど残らないので、既定は 500m。
/// 「どの街から出発したか」は分かるが「どの家か」は分からない粒度。
library;

/// 始点・終点をぼかす既定の半径（メートル）。
const double kDefaultPrivacyRadiusMeters = 500;

/// 経路の両端から [radiusMeters] 以内の点を取り除く。
///
/// 始点から測る基準点は経路の最初の点、終点は最後の点。往復で自宅に戻る
/// 経路でも、両端それぞれで判定するので両方が落ちる。
///
/// 端を落とした結果 2 点未満になった場合は空リストを返す。1点だけ残すと
/// 「そこに居た」という情報がかえって残るため。
List<GeoPoint2D> blurRouteEnds(
  List<GeoPoint2D> route, {
  double radiusMeters = kDefaultPrivacyRadiusMeters,
}) {
  if (route.length < 2) return const [];
  if (radiusMeters <= 0) return List<GeoPoint2D>.from(route);

  final start = route.first;
  final end = route.last;

  final kept = route
      .where((p) =>
          p.distanceTo(start) > radiusMeters && p.distanceTo(end) > radiusMeters)
      .toList();

  return kept.length < 2 ? const [] : kept;
}

/// 住所を市区町村までに切り詰める。
///
/// 「東京都世田谷区北沢2-1-3」→「東京都世田谷区」。
/// 番地が残っていると経路をぼかしても意味が無い。
///
/// 市区町村が見つからない住所（海外・略記など）は、番地らしき部分だけを
/// 落として返す。判別できないときは null を返し、呼び出し側で
/// 「非公開」と表示させる。
String? coarsenAddress(String? address) {
  if (address == null) return null;
  final trimmed = address.trim();
  if (trimmed.isEmpty) return null;

  // 市区町村（郡・町・村を含む）までで切る。
  //
  // **最初に現れた**区切り文字を採用する。政令市なら「横浜市青葉区」まで
  // 残したくなるが、貪欲に取ると「京都市中京区寺町通」のように町名を
  // 含む地名まで拾ってしまう。粗すぎる分には害が無く、細かすぎると
  // 自宅が絞れる。privacy 側に倒して最初の一致で切る。
  final match = RegExp(r'^.*?[市区町村郡]').firstMatch(trimmed);
  if (match != null) return match.group(0);

  // 市区町村が取れない場合は数字以降を落とす。丁目・番地・号は
  // どの表記でも数字を含むため。
  final digitIndex = trimmed.indexOf(RegExp(r'[0-9０-９]'));
  if (digitIndex > 0) return trimmed.substring(0, digitIndex).trim();

  return null;
}

/// 公開表示用にドライブログの位置情報をぼかした結果。
class BlurredRoute {
  /// ぼかし後の経路。空になることもある。
  final List<GeoPoint2D> waypoints;

  /// 市区町村まで切り詰めた出発地。判別できなければ null。
  final String? startAddress;

  /// 市区町村まで切り詰めた到着地。判別できなければ null。
  final String? endAddress;

  const BlurredRoute({
    required this.waypoints,
    required this.startAddress,
    required this.endAddress,
  });

  /// 地図に描ける経路が残っているか。
  bool get hasRoute => waypoints.length >= 2;
}

/// 公開用にぼかした経路と住所を作る。
///
/// [isPublic] が false のときは持ち主自身の閲覧なので何もぼかさない。
/// 自分の記録から自宅が消えていたら、ただ使えないだけになる。
BlurredRoute buildBlurredRoute({
  required List<GeoPoint2D> waypoints,
  required String? startAddress,
  required String? endAddress,
  required bool isPublic,
  double radiusMeters = kDefaultPrivacyRadiusMeters,
}) {
  if (!isPublic) {
    return BlurredRoute(
      waypoints: List<GeoPoint2D>.from(waypoints),
      startAddress: startAddress,
      endAddress: endAddress,
    );
  }
  return BlurredRoute(
    waypoints: blurRouteEnds(waypoints, radiusMeters: radiusMeters),
    startAddress: coarsenAddress(startAddress),
    endAddress: coarsenAddress(endAddress),
  );
}
