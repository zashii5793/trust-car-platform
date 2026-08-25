// Route Privacy Tests
//
// 公開ドライブログから自宅が特定できないことを担保する。
// ここが壊れると「住所を書いていないのに家がバレる」が起きるので、
// 経路共有機能の中で最も落としてはいけない部分。
//
// Coverage:
//   - 始点・終点の近傍が落ちること
//   - 往復（始点＝終点）でも落ちること
//   - 非公開時は何もぼかさないこと
//   - 住所の市区町村までの切り詰め
//   - Edge cases（空、1点、全点が半径内、半径0/負、海外住所）

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/utils/route_privacy.dart';
import 'package:trust_car_platform/models/drive_log.dart';

/// 緯度1度 ≈ 111km。メートル指定で東へ動かす点を作る。
GeoPoint2D _at(double meters) => GeoPoint2D(
      latitude: 35.0 + meters / 111000.0,
      longitude: 139.0,
    );

void main() {
  group('blurRouteEnds', () {
    test('drops points near the start and the end', () {
      final route = [
        _at(0), // 自宅
        _at(200), // 自宅の近く
        _at(3000), // 途中
        _at(6000), // 途中
        _at(9800), // 目的地の近く
        _at(10000), // 目的地
      ];

      final blurred = blurRouteEnds(route, radiusMeters: 500);

      expect(blurred.length, 2);
      // 残ったのは中間の2点だけ。
      expect(blurred.first.distanceTo(route.first), greaterThan(500));
      expect(blurred.last.distanceTo(route.last), greaterThan(500));
    });

    test('drops both ends when the drive returns home', () {
      // 自宅→どこか→自宅。始点と終点が同じでも両端が落ちること。
      final route = [
        _at(0),
        _at(100),
        _at(5000),
        _at(100),
        _at(0),
      ];

      final blurred = blurRouteEnds(route, radiusMeters: 500);

      // 残るのは _at(5000) の1点だけ。1点では公開しない仕様なので空になる。
      expect(blurred, isEmpty);
    });

    test('keeps points outside the radius', () {
      final route = [_at(0), _at(2000), _at(4000), _at(6000)];
      final blurred = blurRouteEnds(route, radiusMeters: 500);
      expect(blurred.length, 2);
    });

    group('Edge Cases', () {
      test('an empty route returns empty', () {
        expect(blurRouteEnds(const []), isEmpty);
      });

      test('a single point returns empty', () {
        // 1点だけ残すと「そこに居た」が残るので落とす。
        expect(blurRouteEnds([_at(0)]), isEmpty);
      });

      test('a route entirely within the radius returns empty', () {
        final route = [_at(0), _at(50), _at(100), _at(0)];
        expect(blurRouteEnds(route, radiusMeters: 500), isEmpty);
      });

      test('leaving only one point returns empty', () {
        final route = [_at(0), _at(3000), _at(6000)];
        // 半径を広げて中間1点しか残らない状況を作る。
        final blurred = blurRouteEnds(route, radiusMeters: 3500);
        expect(blurred, isEmpty);
      });

      test('a zero radius keeps the route as-is', () {
        final route = [_at(0), _at(1000)];
        expect(blurRouteEnds(route, radiusMeters: 0).length, 2);
      });

      test('a negative radius keeps the route as-is', () {
        final route = [_at(0), _at(1000)];
        expect(blurRouteEnds(route, radiusMeters: -100).length, 2);
      });
    });
  });

  group('coarsenAddress', () {
    test('trims a Japanese address down to the municipality', () {
      expect(coarsenAddress('東京都世田谷区北沢2-1-3'), '東京都世田谷区');
    });

    test('cuts a designated city at the city, not the ward', () {
      // 粗いぶんには害が無い。細かすぎるほうが危ない。
      expect(coarsenAddress('神奈川県横浜市青葉区あざみ野1-2-3'), '神奈川県横浜市');
    });

    test('handles 郡 / 町 / 村', () {
      expect(coarsenAddress('長野県北安曇郡白馬村北城4001'), '長野県北安曇郡');
    });

    test('does not leak a street name that contains 町', () {
      // 貪欲に取ると「寺町通」まで拾ってしまう。
      expect(coarsenAddress('京都府京都市中京区寺町通1-1'), '京都府京都市');
    });

    group('Edge Cases', () {
      test('null returns null', () {
        expect(coarsenAddress(null), isNull);
      });

      test('an empty or blank string returns null', () {
        expect(coarsenAddress(''), isNull);
        expect(coarsenAddress('   '), isNull);
      });

      test('an address with no municipality falls back to dropping digits', () {
        expect(coarsenAddress('Some Street 1234'), 'Some Street');
      });

      test('an unrecognizable address returns null', () {
        // 判別できないものを素通しすると番地が残りうる。
        expect(coarsenAddress('自宅'), isNull);
      });

      test('full-width digits are treated as digits', () {
        expect(coarsenAddress('Foo Road １２３'), 'Foo Road');
      });
    });
  });

  group('buildBlurredRoute', () {
    final route = [_at(0), _at(200), _at(4000), _at(8000), _at(10000)];

    test('does not blur anything when the log is private', () {
      // 自分の記録から自宅が消えたら、ただ使えないだけになる。
      final result = buildBlurredRoute(
        waypoints: route,
        startAddress: '東京都世田谷区北沢2-1-3',
        endAddress: '神奈川県鎌倉市由比ガ浜1-1',
        isPublic: false,
      );

      expect(result.waypoints.length, route.length);
      expect(result.startAddress, '東京都世田谷区北沢2-1-3');
      expect(result.endAddress, '神奈川県鎌倉市由比ガ浜1-1');
    });

    test('blurs the route and the addresses when public', () {
      final result = buildBlurredRoute(
        waypoints: route,
        startAddress: '東京都世田谷区北沢2-1-3',
        endAddress: '神奈川県鎌倉市由比ガ浜1-1',
        isPublic: true,
      );

      expect(result.startAddress, '東京都世田谷区');
      expect(result.endAddress, '神奈川県鎌倉市');
      expect(result.waypoints.length, lessThan(route.length));
      for (final p in result.waypoints) {
        expect(p.distanceTo(route.first), greaterThan(400));
        expect(p.distanceTo(route.last), greaterThan(400));
      }
    });

    group('Edge Cases', () {
      test('hasRoute is false when nothing survives blurring', () {
        final result = buildBlurredRoute(
          waypoints: [_at(0), _at(100)],
          startAddress: null,
          endAddress: null,
          isPublic: true,
        );
        expect(result.hasRoute, isFalse);
      });

      test('null addresses stay null', () {
        final result = buildBlurredRoute(
          waypoints: route,
          startAddress: null,
          endAddress: null,
          isPublic: true,
        );
        expect(result.startAddress, isNull);
        expect(result.endAddress, isNull);
      });
    });
  });

  group('GeoPoint2D.distanceTo', () {
    test('matches a known distance', () {
      // 東京駅 → 横浜駅 は約 27km。自前のテイラー展開を dart:math に
      // 置き換えたので、実測値と合うことを固定する。
      const tokyo = GeoPoint2D(latitude: 35.681236, longitude: 139.767125);
      const yokohama = GeoPoint2D(latitude: 35.465786, longitude: 139.622313);

      final meters = tokyo.distanceTo(yokohama);

      expect(meters, greaterThan(26000));
      expect(meters, lessThan(28000));
    });

    test('is zero for the same point', () {
      const p = GeoPoint2D(latitude: 35.0, longitude: 139.0);
      expect(p.distanceTo(p), lessThan(0.001));
    });

    test('is symmetric', () {
      const a = GeoPoint2D(latitude: 35.0, longitude: 139.0);
      const b = GeoPoint2D(latitude: 34.5, longitude: 138.5);
      expect((a.distanceTo(b) - b.distanceTo(a)).abs(), lessThan(0.001));
    });
  });
}
