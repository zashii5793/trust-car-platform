import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/services/ledger_csv_export.dart';
import 'package:trust_car_platform/services/ledger_csv_import.dart';

/// 台帳の書き出し（2026-09-29 プロダクト評価 #8・#2）。
///
/// **書き出した CSV を、そのまま取り込み直せること**を確かめる。
/// やめるときに持ち出した名簿が、次の店（または戻ってきたとき）に
/// 入らなければ、持ち出せたことにならない。
void main() {
  final t0 = DateTime(2026, 1, 1);

  LedgerCustomer customer(
    String id,
    String name, {
    String? kana,
    LedgerCustomerKind kind = LedgerCustomerKind.individual,
    String? contactPerson,
    String? phone,
    String? email,
    String? postalCode,
    String? address,
    String? note,
    String? externalId,
    String? linkedUserId,
  }) =>
      LedgerCustomer(
        id: id,
        kind: kind,
        name: name,
        nameKana: kana,
        contactPerson: contactPerson,
        phone: phone,
        email: email,
        postalCode: postalCode,
        address: address,
        note: note,
        externalId: externalId,
        linkedUserId: linkedUserId,
        createdAt: t0,
        updatedAt: t0,
      );

  LedgerVehicle vehicle(
    String id,
    String customerId, {
    String customerName = '',
    String maker = 'トヨタ',
    String model = 'プリウス',
    String? plate,
    int? year,
    String? modelCode,
    String? vin,
    DateTime? inspectionExpiry,
    DateTime? lastVisitAt,
    int? lastMileage,
    String? externalId,
    DateTime? inspectionNoticeAt,
  }) =>
      LedgerVehicle(
        id: id,
        customerId: customerId,
        customerName: customerName,
        maker: maker,
        model: model,
        plate: plate,
        year: year,
        modelCode: modelCode,
        vin: vin,
        inspectionExpiry: inspectionExpiry,
        lastVisitAt: lastVisitAt,
        lastMileage: lastMileage,
        externalId: externalId,
        inspectionNoticeAt: inspectionNoticeAt,
        inspectionNoticeExpiry:
            inspectionNoticeAt == null ? null : inspectionExpiry,
        createdAt: t0,
        updatedAt: t0,
      );

  /// 書き出した CSV を、取込と同じ手順で読み解く。
  LedgerImportPlan reimport(String csv) {
    final rows = parseCsv(csv);
    final columns = guessColumns(rows.first);
    return buildImportPlan(rows.sublist(1), columns);
  }

  group('buildLedgerCsv — 台帳の全件', () {
    test('先頭に BOM が付く（Excel で文字化けしない）', () {
      final csv = buildLedgerCsv(customers: const [], vehicles: const []);
      expect(csv.startsWith('\u{FEFF}'), isTrue);
    });

    test('見出しは取込の列名と同じで、取込の推測で全項目が当たる', () {
      final csv = buildLedgerCsv(customers: const [], vehicles: const []);
      final header = parseCsv(csv).first;
      final columns = guessColumns(header);
      for (final f in LedgerImportField.values) {
        expect(header[columns[f]!], f.label, reason: f.name);
      }
      // 取込に無い項目（メモ・案内した日）は、取込の列に取られない
      expect(header, containsAll(['メモ', '車検案内日']));
      expect(columns.values, isNot(contains(header.indexOf('メモ'))));
      expect(columns.values, isNot(contains(header.indexOf('車検案内日'))));
    });

    test('1行＝車両1台。2台持ちの顧客は2行になり、取り込むと1人にまとまる', () {
      final c = customer('c_A001', 'サンプル運輸',
          kana: 'サンプルウンユ',
          kind: LedgerCustomerKind.corporate,
          contactPerson: '佐藤',
          phone: '03-1234-5678',
          email: 'info@example.com',
          postalCode: '140-0001',
          address: '東京都品川区北品川1-1-1',
          externalId: 'A001');
      final csv = buildLedgerCsv(customers: [
        c
      ], vehicles: [
        vehicle('v_1', c.id,
            maker: 'トヨタ',
            model: 'ハイエース',
            plate: '品川400さ1',
            year: 2019,
            modelCode: 'GDH201V',
            vin: 'GDH201-1000001',
            inspectionExpiry: DateTime(2027, 1, 10),
            lastVisitAt: DateTime(2026, 3, 1),
            lastMileage: 123456,
            externalId: 'V1'),
        vehicle('v_2', c.id,
            maker: '日産', model: 'キャラバン', plate: '品川400さ2', externalId: 'V2'),
      ]);

      final plan = reimport(csv);
      expect(plan.problems, isEmpty);
      expect(plan.customers, hasLength(1));
      final ic = plan.customers.single;
      expect(ic.externalId, 'A001');
      expect(ic.name, 'サンプル運輸');
      expect(ic.nameKana, 'サンプルウンユ');
      expect(ic.kind, LedgerCustomerKind.corporate);
      expect(ic.contactPerson, '佐藤');
      expect(ic.phone, '03-1234-5678');
      expect(ic.email, 'info@example.com');
      expect(ic.postalCode, '140-0001');
      expect(ic.address, '東京都品川区北品川1-1-1');
      expect(ic.vehicles, hasLength(2));

      final hiace = ic.vehicles.firstWhere((v) => v.model == 'ハイエース');
      expect(hiace.externalId, 'V1');
      expect(hiace.maker, 'トヨタ');
      expect(hiace.plate, '品川400さ1');
      expect(hiace.year, 2019);
      expect(hiace.modelCode, 'GDH201V');
      expect(hiace.vin, 'GDH201-1000001');
      expect(hiace.inspectionExpiry, DateTime(2027, 1, 10));
      expect(hiace.lastVisitAt, DateTime(2026, 3, 1));
      expect(hiace.mileage, 123456);
    });

    test('車の無い顧客も1行で出る（取り込むと顧客だけ入る）', () {
      final csv = buildLedgerCsv(
        customers: [customer('c1', '青木花子', kana: 'アオキハナコ')],
        vehicles: const [],
      );
      final plan = reimport(csv);
      expect(plan.problems, isEmpty);
      expect(plan.customers.single.name, '青木花子');
      expect(plan.customers.single.vehicles, isEmpty);
      expect(plan.customers.single.kind, LedgerCustomerKind.individual);
    });

    test('顧客番号の無い顧客・車両は、台帳のIDを番号の欄に入れる', () {
      final csv = buildLedgerCsv(
        customers: [customer('autoId123', '山田太郎')],
        vehicles: [vehicle('autoVeh9', 'autoId123')],
      );
      final plan = reimport(csv);
      expect(plan.customers.single.externalId, 'autoId123');
      expect(plan.customers.single.vehicles.single.externalId, 'autoVeh9');
    });

    test('メモと車検案内日も書き出す', () {
      final csv = buildLedgerCsv(
        customers: [customer('c1', '山田太郎', note: '平日は夕方以降')],
        vehicles: [
          vehicle('v1', 'c1',
              inspectionExpiry: DateTime(2026, 11, 1),
              inspectionNoticeAt: DateTime(2026, 9, 30)),
        ],
      );
      final rows = parseCsv(csv);
      final header = rows.first;
      expect(rows[1][header.indexOf('メモ')], '平日は夕方以降');
      expect(rows[1][header.indexOf('車検案内日')], '2026/09/30');
    });

    test('顧客はフリガナ順、同じ顧客の車は満了日の近い順', () {
      final csv = buildLedgerCsv(
        customers: [
          customer('c2', '渡辺', kana: 'ワタナベ'),
          customer('c1', '青木', kana: 'アオキ'),
        ],
        vehicles: [
          vehicle('v2', 'c1',
              model: 'あと', inspectionExpiry: DateTime(2027, 5, 1)),
          vehicle('v1', 'c1',
              model: 'さき', inspectionExpiry: DateTime(2026, 12, 1)),
          vehicle('v3', 'c2', model: 'わたなべの車'),
        ],
      );
      final rows = parseCsv(csv).sublist(1);
      final nameCol = parseCsv(csv).first.indexOf('車名');
      expect(rows.map((r) => r[nameCol]).toList(), ['さき', 'あと', 'わたなべの車']);
    });

    group('Edge Cases', () {
      test('顧客も車も無ければ、見出しだけ', () {
        final csv = buildLedgerCsv(customers: const [], vehicles: const []);
        expect(parseCsv(csv), hasLength(1));
      });

      test('カンマ・改行・引用符の入った住所やメモも、取り込むと元に戻る', () {
        final csv = buildLedgerCsv(customers: [
          customer('c1', '山田, 太郎', address: '東京都千代田区\n丸の内1-1', note: '「""至急""」')
        ], vehicles: const []);
        final plan = reimport(csv);
        expect(plan.customers.single.name, '山田, 太郎');
        expect(plan.customers.single.address, '東京都千代田区\n丸の内1-1');
        final rows = parseCsv(csv);
        expect(rows[1][rows.first.indexOf('メモ')], '「""至急""」');
      });

      test('= + - @ で始まる値は式にならないよう印を付け、取り込むと元に戻る', () {
        final csv = buildLedgerCsv(customers: [
          customer('c1', '=HYPERLINK("x")', phone: '+81-90-1234-5678')
        ], vehicles: const []);
        final rows = parseCsv(csv);
        expect(rows[1][rows.first.indexOf('顧客名')], "'=HYPERLINK(\"x\")");

        final plan = reimport(csv);
        expect(plan.customers.single.name, '=HYPERLINK("x")');
        expect(plan.customers.single.phone, '+81-90-1234-5678');
      });

      test('顧客のいない車（持ち主が消えた車）も落とさずに出す', () {
        final csv = buildLedgerCsv(
          customers: const [],
          vehicles: [vehicle('v1', 'gone', customerName: '旧顧客')],
        );
        final plan = reimport(csv);
        expect(plan.customers.single.name, '旧顧客');
        expect(plan.customers.single.vehicles, hasLength(1));
      });
    });
  });

  group('buildInspectionNoticeCsv — 車検案内の宛名', () {
    test('BOM 付きで、業者に渡す7列（氏名・郵便番号・住所・電話・車名・登録番号・満了日）', () {
      final c = customer('c1', '山田太郎',
          phone: '090-1111-2222',
          postalCode: '100-0001',
          address: '東京都千代田区千代田1-1');
      final v = vehicle('v1', 'c1',
          maker: 'MINI',
          model: 'クーパー',
          plate: '品川300あ1234',
          inspectionExpiry: DateTime(2026, 11, 5));
      final csv = buildInspectionNoticeCsv(
          [InspectionNoticeTarget(customer: c, vehicle: v)]);

      expect(csv.startsWith('\u{FEFF}'), isTrue);
      final rows = parseCsv(csv);
      expect(rows.first, ['氏名', '郵便番号', '住所', '電話番号', '車名', '登録番号', '車検満了日']);
      expect(rows[1], [
        '山田太郎',
        '100-0001',
        '東京都千代田区千代田1-1',
        '090-1111-2222',
        'MINI クーパー',
        '品川300あ1234',
        '2026/11/05',
      ]);
    });

    test('満了日の近い順に並ぶ', () {
      final c = customer('c1', '山田');
      final csv = buildInspectionNoticeCsv([
        InspectionNoticeTarget(
            customer: c,
            vehicle: vehicle('v2', 'c1',
                model: 'あと', inspectionExpiry: DateTime(2026, 12, 1))),
        InspectionNoticeTarget(
            customer: c,
            vehicle: vehicle('v1', 'c1',
                model: 'さき', inspectionExpiry: DateTime(2026, 10, 1))),
      ]);
      final rows = parseCsv(csv).sublist(1);
      expect(rows.map((r) => r[4]).toList(), ['トヨタ さき', 'トヨタ あと']);
    });

    group('Edge Cases', () {
      test('対象が無ければ、見出しだけ', () {
        expect(parseCsv(buildInspectionNoticeCsv(const [])), hasLength(1));
      });

      test('空の項目は空欄のまま（「null」と書かない）', () {
        final csv = buildInspectionNoticeCsv([
          InspectionNoticeTarget(
            customer: customer('c1', '山田'),
            vehicle: vehicle('v1', 'c1'),
          ),
        ]);
        expect(csv, isNot(contains('null')));
        expect(parseCsv(csv)[1], ['山田', '', '', '', 'トヨタ プリウス', '', '']);
      });
    });
  });
}
