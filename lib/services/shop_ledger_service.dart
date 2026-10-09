import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/shop_ledger.dart';
import 'ledger_csv_import.dart';

/// 一覧の1ページ分。
///
/// [cursor] は次のページを取るときにそのまま渡す。中身（DocumentSnapshot）を
/// 画面に触らせないために Object で持つ。
class LedgerPage<T> {
  final List<T> items;
  final Object? cursor;
  final bool hasMore;

  const LedgerPage({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });
}

/// 顧客一覧の並べ方。
enum LedgerCustomerSort {
  /// フリガナ順。
  kana('50音順'),

  /// 最近来た順。
  recentVisit('最近来た順'),

  /// 登録の新しい順。
  newest('登録の新しい順');

  final String label;
  const LedgerCustomerSort(this.label);
}

/// 店の顧客台帳の読み書き（`docs/SHOP_CRM_DESIGN_2026-09-27.md`）。
///
/// **何千人の顧客を持つ店で遅くならないこと**を先に決めてある:
///
/// - 一覧は [pageSize] 件ずつ。全件は読まない
/// - 件数は `count()` の集計で出す。4,000件を読まずに「4,000名」を出す
/// - 並べ替えと検索は、単一フィールドのインデックスで引ける形にしてある
class ShopLedgerService {
  final FirebaseFirestore _firestore;
  final DateTime Function() _now;

  ShopLedgerService({
    required FirebaseFirestore firestore,
    DateTime Function()? now,
  })  : _firestore = firestore,
        _now = now ?? DateTime.now;

  static const int pageSize = 20;

  /// Firestore の1バッチの上限は500件。余裕を見て400で切る。
  static const int _batchLimit = 400;

  CollectionReference<Map<String, dynamic>> _customers(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('customers');

  CollectionReference<Map<String, dynamic>> _vehicles(String shopId) =>
      _firestore
          .collection('shops')
          .doc(shopId)
          .collection('customer_vehicles');

  /// 整備管理ソフトの顧客番号から、ドキュメントIDを作る。
  ///
  /// **取込を何度やり直しても二重にならない**よう、番号が同じなら同じIDにする。
  /// `/` はパスの区切りになるので置き換える。
  static String idForExternal(String prefix, String externalId) {
    final safe = externalId.trim().replaceAll(RegExp(r'[/\s]'), '_');
    return '${prefix}_$safe';
  }

  // ---------------------------------------------------------------------------
  // 顧客
  // ---------------------------------------------------------------------------

  /// 顧客の一覧を1ページ分返す。
  ///
  /// [search] があれば、並べ方は無視して、漢字・フリガナの姓や名・担当者・
  /// 電話番号の前方一致で引き、フリガナ順に並べる
  /// （`searchKeys array-contains`。[LedgerSearch.customerKeys]）。
  Future<Result<LedgerPage<LedgerCustomer>, AppError>> listCustomers({
    required String shopId,
    LedgerCustomerSort sort = LedgerCustomerSort.kana,
    String? search,
    Object? cursor,
    int limit = pageSize,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _customers(shopId);
      final key = search == null ? '' : LedgerSearch.queryKey(search);

      if (key.isNotEmpty) {
        final probe = _probeKey(key);
        q = q.where('searchKeys', arrayContains: probe).orderBy('searchKey');
        final page = await _page(
          q,
          cursor: cursor,
          limit: limit,
          map: LedgerCustomer.fromMap,
        );
        if (probe == key) return Result.success(page);
        // Only the first maxPrefixLength characters are stored; check the
        // rest here (a page may come back shorter than [limit]).
        return Result.success(LedgerPage(
          items: page.items
              .where((c) => LedgerSearch.customerMatches(c, key))
              .toList(),
          cursor: page.cursor,
          hasMore: page.hasMore,
        ));
      } else {
        q = switch (sort) {
          LedgerCustomerSort.kana => q.orderBy('searchKey'),
          LedgerCustomerSort.recentVisit =>
            q.orderBy('lastVisitAt', descending: true),
          LedgerCustomerSort.newest => q.orderBy('createdAt', descending: true),
        };
      }

      return Result.success(await _page(
        q,
        cursor: cursor,
        limit: limit,
        map: LedgerCustomer.fromMap,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// Customers whose name looks like [search], for when the search found
  /// nobody: the query is shortened from the end one character at a time
  /// ("青木和男" → "青木和" → "青木"), up to [limit] people.
  ///
  /// Shown above "add as a new customer" so that a name typed a little
  /// differently does not become a second record of the same person.
  Future<Result<List<LedgerCustomer>, AppError>> similarCustomers({
    required String shopId,
    required String search,
    int limit = 5,
  }) async {
    final runes = LedgerSearch.queryKey(search).runes.toList();
    if (shopId.isEmpty || runes.length < 2 || limit <= 0) {
      return const Result.success([]);
    }
    try {
      final longest = runes.length - 1 < LedgerSearch.maxPrefixLength
          ? runes.length - 1
          : LedgerSearch.maxPrefixLength;
      for (var n = longest; n >= 1; n--) {
        final snap = await _customers(shopId)
            .where('searchKeys',
                arrayContains: String.fromCharCodes(runes.take(n)))
            .orderBy('searchKey')
            .limit(limit)
            .get();
        if (snap.docs.isNotEmpty) {
          return Result.success(snap.docs
              .map((d) => LedgerCustomer.fromMap(d.id, d.data()))
              .toList());
        }
      }
      return const Result.success([]);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  static String _probeKey(String key) {
    final runes = key.runes;
    return runes.length <= LedgerSearch.maxPrefixLength
        ? key
        : String.fromCharCodes(runes.take(LedgerSearch.maxPrefixLength));
  }

  /// Adds the search fields (searchKeys / plateTails, 2026-10-09) to
  /// customers and vehicles written before they existed. Returns how many
  /// documents were rewritten.
  ///
  /// Two `count()` queries per collection tell whether anything is
  /// missing, so once a shop is done this costs a few reads. The first
  /// time it reads the whole collection once (4,000 customers ≈ 4,000
  /// reads and writes). `updatedAt` is left alone: nothing the shop sees
  /// has changed.
  Future<Result<int, AppError>> ensureSearchFields(String shopId) async {
    if (shopId.isEmpty) {
      return const Result.failure(AppError.validation('店が選ばれていません'));
    }
    try {
      var rewritten = 0;
      rewritten += await _ensureVersion(_customers(shopId), (id, m) {
        final c = LedgerCustomer.fromMap(id, m);
        return {'searchKey': c.searchKey, 'searchKeys': c.searchKeys};
      });
      rewritten += await _ensureVersion(_vehicles(shopId), (id, m) {
        final plate = m['plate'] as String?;
        return {
          'plateKey': plate == null ? null : LedgerSearch.plateKey(plate),
          'plateNumber': plate == null ? null : LedgerSearch.plateNumber(plate),
          'plateTails':
              plate == null ? const <String>[] : LedgerSearch.plateTails(plate),
        };
      });
      return Result.success(rewritten);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// Fills `lastInspectionAt` / `lastInspectionDueAt` (2026-10-09) on
  /// vehicles written before they existed, from the records already
  /// stored. Returns how many vehicles got the fields.
  ///
  /// Without them the loss report cannot see cars that came back for their
  /// inspection (their expiry moved two years on) and counts every expired
  /// car as lost. The next history import fills them too; this runs on
  /// opening the ledger so the report is right before that. A marker
  /// (`inspectionFieldsVersion`) and two `count()` queries make it a few
  /// reads once every vehicle is done.
  Future<Result<int, AppError>> ensureInspectionFields(String shopId) async {
    if (shopId.isEmpty) {
      return const Result.failure(AppError.validation('店が選ばれていません'));
    }
    try {
      final col = _vehicles(shopId);
      final counts = await Future.wait([
        col.count().get(),
        col
            .where('inspectionFieldsVersion',
                isEqualTo: _inspectionFieldsVersion)
            .count()
            .get(),
      ]);
      if ((counts[0].count ?? 0) == (counts[1].count ?? 0)) {
        return const Result.success(0);
      }

      final pending = (await col.get())
          .docs
          .where((d) =>
              d.data()['inspectionFieldsVersion'] != _inspectionFieldsVersion)
          .toList();
      final unknown = <String>{
        for (final d in pending)
          if (!d.data().containsKey('lastInspectionAt')) d.id,
      };
      final latest = await _latestInspections(
        shopId,
        unknown,
        readAll: unknown.length > _readAllRecordsAbove,
      );
      for (var i = 0; i < pending.length; i += _batchLimit) {
        final batch = _firestore.batch();
        for (final d in pending.skip(i).take(_batchLimit)) {
          final fields = <String, dynamic>{
            'inspectionFieldsVersion': _inspectionFieldsVersion,
          };
          if (unknown.contains(d.id)) {
            final at = latest[d.id];
            final due = at == null
                ? null
                : inspectionDueFor(
                    expiry:
                        LedgerVehicle.fromMap(d.id, d.data()).inspectionExpiry,
                    inspectedAt: at,
                  );
            fields['lastInspectionAt'] =
                at == null ? null : Timestamp.fromDate(at);
            fields['lastInspectionDueAt'] =
                due == null ? null : Timestamp.fromDate(due);
          }
          batch.set(d.reference, fields, SetOptions(merge: true));
        }
        await batch.commit();
      }
      return Result.success(unknown.length);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  static const int _inspectionFieldsVersion = 1;

  Future<int> _ensureVersion(
    CollectionReference<Map<String, dynamic>> col,
    Map<String, dynamic> Function(String id, Map<String, dynamic> m) fields,
  ) async {
    final counts = await Future.wait([
      col.count().get(),
      col.where('searchVersion', isEqualTo: LedgerSearch.version).count().get(),
    ]);
    if ((counts[0].count ?? 0) == (counts[1].count ?? 0)) return 0;

    final stale = (await col.get())
        .docs
        .where((d) => d.data()['searchVersion'] != LedgerSearch.version)
        .toList();
    for (var i = 0; i < stale.length; i += _batchLimit) {
      final batch = _firestore.batch();
      for (final d in stale.skip(i).take(_batchLimit)) {
        batch.set(
          d.reference,
          {
            ...fields(d.id, d.data()),
            'searchVersion': LedgerSearch.version,
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
    return stale.length;
  }

  /// しばらく来ていない顧客。[since] より前が最後の来店だった人を、古い順に。
  ///
  /// **一度も来店記録の無い人は出さない。** 取り込んだだけで実績が無い人を
  /// 「離れた客」と呼ぶと、声をかける相手を間違える。
  Future<Result<LedgerPage<LedgerCustomer>, AppError>> listLapsedCustomers({
    required String shopId,
    required DateTime since,
    Object? cursor,
    int limit = pageSize,
  }) async {
    try {
      final q = _customers(shopId)
          .where('lastVisitAt', isLessThan: Timestamp.fromDate(since))
          .orderBy('lastVisitAt');
      return Result.success(await _page(
        q,
        cursor: cursor,
        limit: limit,
        map: LedgerCustomer.fromMap,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  Future<Result<LedgerCustomer, AppError>> getCustomer({
    required String shopId,
    required String customerId,
  }) async {
    try {
      final doc = await _customers(shopId).doc(customerId).get();
      final data = doc.data();
      if (!doc.exists || data == null) {
        return const Result.failure(
          AppError.notFound('customer not found', resourceType: 'customer'),
        );
      }
      return Result.success(LedgerCustomer.fromMap(doc.id, data));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 顧客を登録する。[externalId] があれば、それを元にIDを決める。
  Future<Result<LedgerCustomer, AppError>> createCustomer({
    required String shopId,
    required LedgerCustomerKind kind,
    required String name,
    String? nameKana,
    String? contactPerson,
    String? phone,
    String? email,
    String? postalCode,
    String? address,
    String? note,
    String? externalId,
    LedgerSource source = LedgerSource.manual,
  }) async {
    final error = validateName(name);
    if (error != null) {
      return Result.failure(AppError.validation(error, field: 'name'));
    }

    try {
      final ext = externalId?.trim();
      final ref = (ext != null && ext.isNotEmpty)
          ? _customers(shopId).doc(idForExternal('c', ext))
          : _customers(shopId).doc();
      final now = _now();
      final customer = LedgerCustomer(
        id: ref.id,
        kind: kind,
        name: name.trim(),
        nameKana: nameKana,
        contactPerson: contactPerson,
        phone: phone,
        email: email,
        postalCode: postalCode,
        address: address,
        note: note,
        externalId: ext,
        source: source,
        createdAt: now,
        updatedAt: now,
      );
      await ref.set(customer.toMap());
      return Result.success(customer);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 顧客の基本情報を書き換える。
  ///
  /// 名前が変わったら、車両に写してある名前も揃える（一覧で顧客を
  /// 引き直さないために写してあるので、ずれると別人に見える）。
  Future<Result<LedgerCustomer, AppError>> updateCustomer({
    required String shopId,
    required LedgerCustomer customer,
  }) async {
    final error = validateName(customer.name);
    if (error != null) {
      return Result.failure(AppError.validation(error, field: 'name'));
    }

    try {
      final ref = _customers(shopId).doc(customer.id);
      final before = await ref.get();
      final previousName = before.data()?['name'] as String?;

      final updated = customer.copyWith(updatedAt: _now());
      final map = updated.toMap()
        // 作成時の情報と、車両から計算する値は、ここでは触らない。
        ..remove('createdAt')
        ..remove('source')
        ..remove('vehicleCount')
        ..remove('nextInspectionAt')
        ..remove('lastVisitAt')
        ..remove('linkedUserId')
        ..remove('isLinked');
      await ref.update(map);

      if (previousName != null && previousName != updated.name) {
        await _renameVehicles(shopId, updated.id, updated.name);
      }
      return Result.success(updated);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 顧客を消す。**その顧客の車両も一緒に消す**（持ち主のいない車を残さない）。
  Future<Result<void, AppError>> deleteCustomer({
    required String shopId,
    required String customerId,
  }) async {
    try {
      for (;;) {
        final snap = await _vehicles(shopId)
            .where('customerId', isEqualTo: customerId)
            .limit(_batchLimit)
            .get();
        if (snap.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
      await _customers(shopId).doc(customerId).delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 画面上部に出す件数。**4,000件あっても読み取りは4回で済む。**
  Future<Result<LedgerCounts, AppError>> counts(String shopId) async {
    try {
      final col = _customers(shopId);
      final results = await Future.wait([
        col.count().get(),
        col
            .where('kind', isEqualTo: LedgerCustomerKind.individual.name)
            .count()
            .get(),
        col
            .where('kind', isEqualTo: LedgerCustomerKind.corporate.name)
            .count()
            .get(),
        col.where('isLinked', isEqualTo: true).count().get(),
      ]);
      return Result.success(LedgerCounts(
        total: results[0].count ?? 0,
        individual: results[1].count ?? 0,
        corporate: results[2].count ?? 0,
        linked: results[3].count ?? 0,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // 車両
  // ---------------------------------------------------------------------------

  /// ある顧客の車両。法人でも数十台なので、ページングせずに返す。
  Future<Result<List<LedgerVehicle>, AppError>> vehiclesOf({
    required String shopId,
    required String customerId,
  }) async {
    try {
      final snap = await _vehicles(shopId)
          .where('customerId', isEqualTo: customerId)
          .get();
      final list = snap.docs
          .map((d) => LedgerVehicle.fromMap(d.id, d.data()))
          .toList()
        ..sort(_byInspection);
      return Result.success(list);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 車検の近い順。[from] 以降に満了する車を、顧客をまたいで並べる。
  Future<Result<LedgerPage<LedgerVehicle>, AppError>> listVehiclesByInspection({
    required String shopId,
    required DateTime from,
    Object? cursor,
    int limit = pageSize,
  }) async {
    try {
      final start = DateTime(from.year, from.month, from.day);
      final q = _vehicles(shopId)
          .where('inspectionExpiry',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .orderBy('inspectionExpiry');
      return Result.success(await _page(
        q,
        cursor: cursor,
        limit: limit,
        map: LedgerVehicle.fromMap,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// ナンバー末尾の番号で車両を引く。末尾の2〜4桁のどれでも当たる
  /// （「35」「335」「63-35」→ 63-35 の車。`plateTails array-contains`）。
  /// 1桁は、番号がその1桁の車だけ（末尾1桁では店の1割の車が当たる）。
  Future<Result<List<LedgerVehicle>, AppError>> findVehiclesByPlateNumber({
    required String shopId,
    required String number,
    int limit = pageSize,
  }) async {
    final key = LedgerSearch.plateNumber(number);
    if (key == null || limit <= 0) return const Result.success([]);
    try {
      final q = key.length == 1
          ? _vehicles(shopId).where('plateNumber', isEqualTo: key)
          : _vehicles(shopId).where('plateTails', arrayContains: key);
      final snap = await q.limit(limit).get();
      return Result.success(
        snap.docs.map((d) => LedgerVehicle.fromMap(d.id, d.data())).toList(),
      );
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 車両を登録または更新し、顧客の要約値（台数・次の車検・最終来店）を作り直す。
  Future<Result<LedgerVehicle, AppError>> saveVehicle({
    required String shopId,
    required String customerId,
    String? vehicleId,
    required String maker,
    required String model,
    String? plate,
    int? year,
    String? modelCode,
    String? vin,
    DateTime? inspectionExpiry,
    DateTime? lastVisitAt,
    int? lastMileage,
    String? externalId,
  }) async {
    if (maker.trim().isEmpty || model.trim().isEmpty) {
      return const Result.failure(
        AppError.validation('メーカーと車種を入力してください', field: 'model'),
      );
    }

    try {
      final customerDoc = await _customers(shopId).doc(customerId).get();
      final customerData = customerDoc.data();
      if (!customerDoc.exists || customerData == null) {
        return const Result.failure(
          AppError.notFound('customer not found', resourceType: 'customer'),
        );
      }

      final ext = externalId?.trim();
      final ref = vehicleId != null
          ? _vehicles(shopId).doc(vehicleId)
          : (ext != null && ext.isNotEmpty)
              ? _vehicles(shopId).doc(idForExternal('v', ext))
              : _vehicles(shopId).doc();

      final existing = await ref.get();
      final now = _now();
      final before = existing.exists
          ? LedgerVehicle.fromMap(ref.id, existing.data()!)
          : null;
      final createdAt = before?.createdAt ?? now;

      final vehicle = LedgerVehicle(
        id: ref.id,
        customerId: customerId,
        customerName: customerData['name'] as String? ?? '',
        plate: plate,
        maker: maker.trim(),
        model: model.trim(),
        year: year,
        modelCode: modelCode,
        vin: vin,
        inspectionExpiry: inspectionExpiry,
        lastVisitAt: lastVisitAt,
        lastMileage: lastMileage,
        externalId: ext,
        // 丸ごと書き直すので、案内した日は前のものを引き継ぐ（消さない）
        inspectionNoticeAt: before?.inspectionNoticeAt,
        inspectionNoticeExpiry: before?.inspectionNoticeExpiry,
        lastInspectionAt: before?.lastInspectionAt,
        lastInspectionDueAt: before?.lastInspectionDueAt,
        createdAt: createdAt,
        updatedAt: now,
      );
      final data = vehicle.toMap();
      // A stored null ("imported, no inspection") must survive the full
      // overwrite, or the loss report would fall back to reading records.
      final raw = existing.data() ?? const <String, dynamic>{};
      for (final key in const ['lastInspectionAt', 'lastInspectionDueAt']) {
        if (raw.containsKey(key)) data.putIfAbsent(key, () => raw[key]);
      }
      await ref.set(data);
      await refreshSummary(shopId: shopId, customerId: customerId);
      return Result.success(vehicle);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  Future<Result<void, AppError>> deleteVehicle({
    required String shopId,
    required LedgerVehicle vehicle,
  }) async {
    try {
      await _vehicles(shopId).doc(vehicle.id).delete();
      await refreshSummary(shopId: shopId, customerId: vehicle.customerId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 顧客の台数・次の車検・最終来店を、車両から計算し直して書き込む。
  Future<void> refreshSummary({
    required String shopId,
    required String customerId,
  }) async {
    final snap = await _vehicles(shopId)
        .where('customerId', isEqualTo: customerId)
        .get();
    final vehicles =
        snap.docs.map((d) => LedgerVehicle.fromMap(d.id, d.data()));
    final summary = LedgerCustomerSummary.of(vehicles, today: _now());
    await _customers(shopId).doc(customerId).update({
      'vehicleCount': summary.vehicleCount,
      'nextInspectionAt': summary.nextInspectionAt != null
          ? Timestamp.fromDate(summary.nextInspectionAt!)
          : null,
      'lastVisitAt': summary.lastVisitAt != null
          ? Timestamp.fromDate(summary.lastVisitAt!)
          : null,
      'updatedAt': Timestamp.fromDate(_now()),
    });
  }

  // ---------------------------------------------------------------------------
  // CSV 取込
  // ---------------------------------------------------------------------------

  /// 読み解いた CSV（[plan]）を台帳に書き込む。
  ///
  /// - **やり直しても二重にならない**。顧客番号・車両番号（無ければ名前＋電話・
  ///   ナンバー）からIDを決め、同じIDなら上書きする
  /// - **店が手で入れた情報は消さない**。メモ・アプリとのつながり・登録日は
  ///   取込で触らない（merge で書く）
  /// - 顧客の要約値（台数・次の車検・最終来店）は、既にある車両と合わせて
  ///   計算し直す
  ///
  /// 既存の顧客と車両を1回ずつ全件読む。取込は店が最初に1回やる作業なので、
  /// 読み取りの回数よりも、上書きの判断を正しくすることを優先している。
  Future<Result<LedgerImportResult, AppError>> importPlan({
    required String shopId,
    required LedgerImportPlan plan,
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      final existingCustomers = {
        for (final d in (await _customers(shopId).get()).docs) d.id: d.data(),
      };
      final existingVehicles = <String, LedgerVehicle>{
        for (final d in (await _vehicles(shopId).get()).docs)
          d.id: LedgerVehicle.fromMap(d.id, d.data()),
      };

      // 顧客ごとの既存車両。顧客のたびに全車両をなめると、
      // 4,000人×10,000台で4,000万回のループになる。
      final vehiclesByCustomer = <String, Map<String, LedgerVehicle>>{};
      for (final v in existingVehicles.values) {
        vehiclesByCustomer.putIfAbsent(v.customerId, () => {})[v.id] = v;
      }
      // 車が別の顧客へ移った（名義変更など）ときに、移る前の顧客の
      // 要約値も直すため、どこから移ったかを覚えておく。
      final movedFrom = <String>{};

      final now = _now();
      final nowTs = Timestamp.fromDate(now);
      final writes =
          <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[];
      var created = 0;
      var updated = 0;
      var vehicleCount = 0;

      for (final c in plan.customers) {
        // 台帳の書き出しは、顧客番号の無い（手で登録した）顧客の番号の欄に
        // 台帳のIDを入れる。そのIDの顧客が顧客番号なしで既にいれば、
        // その人に書き戻す（取り込み直すたびに同じ人が増えないように）。
        final byDocId = c.externalId != null &&
            existingCustomers[c.externalId!] != null &&
            existingCustomers[c.externalId!]!['externalId'] == null;
        final cid =
            byDocId ? c.externalId! : idForExternal('c', c.stableExternalId);
        final isNew = !existingCustomers.containsKey(cid);
        isNew ? created++ : updated++;

        // この顧客の車両: 既にあるもの（取込で上書きされないもの）＋今回の分
        final vehicles = vehiclesByCustomer.putIfAbsent(cid, () => {});
        for (final iv in c.vehicles) {
          // 顧客と同じ。車両番号の欄に台帳のIDが入っていれば、その車に書き戻す
          final vehicleByDocId = iv.externalId != null &&
              existingVehicles[iv.externalId!] != null &&
              existingVehicles[iv.externalId!]!.externalId == null;
          final vid = vehicleByDocId
              ? iv.externalId!
              : idForExternal('v', iv.stableExternalId(c.key));
          final before = existingVehicles[vid];
          final vehicle = LedgerVehicle(
            id: vid,
            customerId: cid,
            customerName: c.name,
            plate: iv.plate,
            maker: iv.maker,
            model: iv.model,
            year: iv.year,
            modelCode: iv.modelCode,
            vin: iv.vin,
            inspectionExpiry: iv.inspectionExpiry,
            lastVisitAt: iv.lastVisitAt,
            lastMileage: iv.mileage,
            externalId: vehicleByDocId
                ? null
                : iv.externalId ?? iv.stableExternalId(c.key),
            createdAt: before?.createdAt ?? now,
            updatedAt: now,
          );
          if (before != null && before.customerId != cid) {
            vehiclesByCustomer[before.customerId]?.remove(vid);
            movedFrom.add(before.customerId);
          }
          vehicles[vid] = vehicle;
          existingVehicles[vid] = vehicle;
          writes.add((_vehicles(shopId).doc(vid), vehicle.toMap()));
          vehicleCount++;
        }

        final summary = LedgerCustomerSummary.of(vehicles.values, today: now);
        final probe = LedgerCustomer(
          id: cid,
          kind: c.kind,
          name: c.name,
          nameKana: c.nameKana,
          contactPerson: c.contactPerson,
          phone: c.phone,
          createdAt: now,
          updatedAt: now,
        );
        final data = <String, dynamic>{
          'kind': c.kind.name,
          'name': c.name,
          'nameKana': c.nameKana,
          'searchKey': probe.searchKey,
          'searchKeys': probe.searchKeys,
          'searchVersion': LedgerSearch.version,
          'contactPerson': c.contactPerson,
          'phone': c.phone,
          'email': c.email,
          'postalCode': c.postalCode,
          'address': c.address,
          // 台帳のIDで書き戻した顧客は、顧客番号なしのまま
          if (!byDocId) 'externalId': c.stableExternalId,
          'vehicleCount': summary.vehicleCount,
          'nextInspectionAt': summary.nextInspectionAt == null
              ? null
              : Timestamp.fromDate(summary.nextInspectionAt!),
          'lastVisitAt': summary.lastVisitAt == null
              ? null
              : Timestamp.fromDate(summary.lastVisitAt!),
          'updatedAt': nowTs,
          if (isNew) ...{
            'createdAt': nowTs,
            'source': LedgerSource.csv.name,
            'linkedUserId': null,
            'isLinked': false,
          },
        };
        writes.add((_customers(shopId).doc(cid), data));
      }

      for (final cid in movedFrom) {
        if (!existingCustomers.containsKey(cid)) continue;
        final summary = LedgerCustomerSummary.of(
          vehiclesByCustomer[cid]?.values ?? const [],
          today: now,
        );
        writes.add((
          _customers(shopId).doc(cid),
          {
            'vehicleCount': summary.vehicleCount,
            'nextInspectionAt': summary.nextInspectionAt == null
                ? null
                : Timestamp.fromDate(summary.nextInspectionAt!),
            'lastVisitAt': summary.lastVisitAt == null
                ? null
                : Timestamp.fromDate(summary.lastVisitAt!),
            'updatedAt': nowTs,
          },
        ));
      }

      var done = 0;
      onProgress?.call(0, writes.length);
      for (var i = 0; i < writes.length; i += _batchLimit) {
        final batch = _firestore.batch();
        for (final (ref, data) in writes.skip(i).take(_batchLimit)) {
          batch.set(ref, data, SetOptions(merge: true));
        }
        await batch.commit();
        done = (i + _batchLimit).clamp(0, writes.length);
        onProgress?.call(done, writes.length);
      }

      return Result.success(LedgerImportResult(
        createdCustomers: created,
        updatedCustomers: updated,
        vehicles: vehicleCount,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // 整備履歴（伝票）の取込
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _records(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('service_records');

  /// 整備履歴を `shops/{shopId}/service_records` に書き込む。
  ///
  /// どの車の作業かは、台帳と突き合わせて決める（車両番号 → ナンバー →
  /// 顧客番号の順）。**先に顧客名簿を取り込んでおく**必要がある。
  /// 決められない行は書かずに、何行目かを添えて返す。
  ///
  /// 伝票番号があればそれで、無ければ「車・日付・内容・金額」で同じ伝票と
  /// みなす。やり直しても二重にならない。
  ///
  /// 車ごとの最終来店日・走行距離と、顧客の要約値も作り直す
  /// （「しばらく来ていない」の判定がこれで正しくなる）。
  Future<Result<LedgerHistoryResult, AppError>> importHistory({
    required String shopId,
    required LedgerHistoryPlan plan,
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      final vehicleDocs = (await _vehicles(shopId).get()).docs;
      final vehicles = <String, LedgerVehicle>{
        for (final d in vehicleDocs)
          d.id: LedgerVehicle.fromMap(d.id, d.data()),
      };
      // Vehicles from before `lastInspectionAt` existed (2026-10-09).
      final unknownInspection = <String>{
        for (final d in vehicleDocs)
          if (!d.data().containsKey('lastInspectionAt')) d.id,
      };
      final customerIdByExt = <String, String>{};
      for (final d in (await _customers(shopId).get()).docs) {
        final ext = d.data()['externalId'] as String?;
        if (ext != null) customerIdByExt[ext] = d.id;
      }
      final byExt = <String, LedgerVehicle>{};
      final byPlate = <String, LedgerVehicle>{};
      final byCustomer = <String, List<LedgerVehicle>>{};
      for (final v in vehicles.values) {
        if (v.externalId != null) byExt[v.externalId!] = v;
        if (v.plate != null) byPlate[LedgerSearch.plateKey(v.plate!)] = v;
        byCustomer.putIfAbsent(v.customerId, () => []).add(v);
      }

      final problems = <LedgerImportProblem>[];
      final writes =
          <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[];
      final latest = <String, LedgerHistoryRow>{};
      final inspectedAt = <String, DateTime>{};
      final now = Timestamp.fromDate(_now());
      final recordIds = <String>{};

      for (final row in plan.rows) {
        LedgerVehicle? v;
        if (row.vehicleExternalId != null) v = byExt[row.vehicleExternalId!];
        if (v == null && row.plate != null) {
          v = byPlate[LedgerSearch.plateKey(row.plate!)];
        }
        if (v == null && row.customerExternalId != null) {
          final cid = customerIdByExt[row.customerExternalId!];
          final list = cid == null ? null : byCustomer[cid];
          if (list != null && list.length == 1) {
            v = list.single;
          } else if (list != null && list.length > 1) {
            problems.add(LedgerImportProblem(row.line,
                '顧客番号「${row.customerExternalId}」の車が${list.length}台あり、どの車か決められません（登録番号か車両番号の列を入れてください）'));
            continue;
          }
        }
        if (v == null) {
          problems.add(LedgerImportProblem(
              row.line, '台帳にこの車が見つかりません（先に顧客名簿を取り込んでください）'));
          continue;
        }

        final key = row.slipNumber ??
            '${v.id}|${row.date.millisecondsSinceEpoch}|${row.type}|${row.total}';
        final recordId = idForExternal('r', key);
        recordIds.add(recordId);
        writes.add((
          _records(shopId).doc(recordId),
          {
            'customerId': v.customerId,
            'customerVehicleId': v.id,
            'date': Timestamp.fromDate(row.date),
            'type': row.type,
            'totalCost': row.total,
            'mileage': row.mileage,
            // 車種レポートの集計で車両を引き直さずに済むよう写しておく
            'maker': v.maker,
            'model': v.model,
            'year': v.year,
            'externalId': row.slipNumber,
            'source': LedgerSource.csv.name,
            'updatedAt': now,
          },
        ));
        final prev = latest[v.id];
        if (prev == null || row.date.isAfter(prev.date)) latest[v.id] = row;
        if (isInspectionWork(row.type)) {
          final seen = inspectedAt[v.id];
          if (seen == null || row.date.isAfter(seen)) {
            inspectedAt[v.id] = row.date;
          }
        }
      }

      final vehicleUpdates = <String, Map<String, dynamic>>{};

      // 車ごとの最終来店・走行距離
      final touchedCustomers = <String>{};
      for (final entry in latest.entries) {
        final v = vehicles[entry.key]!;
        final row = entry.value;
        if (v.lastVisitAt != null && !row.date.isAfter(v.lastVisitAt!)) {
          continue;
        }
        final updated = LedgerVehicle.fromMap(v.id, {
          ...v.toMap(),
          'lastVisitAt': Timestamp.fromDate(row.date),
          if (row.mileage != null) 'lastMileage': row.mileage,
        });
        vehicles[v.id] = updated;
        vehicleUpdates.putIfAbsent(v.id, () => {}).addAll({
          'lastVisitAt': Timestamp.fromDate(row.date),
          if (row.mileage != null) 'lastMileage': row.mileage,
          'updatedAt': now,
        });
        touchedCustomers.add(v.customerId);
      }

      // The latest inspection per vehicle, kept on the vehicle so the loss
      // report reads vehicles only. Vehicles from before this field get it
      // from the records already stored (a one-time migration); the field
      // is written even when there is no inspection (null), so this runs
      // once per vehicle.
      final fromStored = await _latestInspections(
        shopId,
        unknownInspection,
        readAll: unknownInspection.length > _readAllRecordsAbove,
      );
      for (final v in vehicles.values) {
        final unknown = unknownInspection.contains(v.id);
        var at = unknown ? fromStored[v.id] : v.lastInspectionAt;
        final imported = inspectedAt[v.id];
        if (imported != null && (at == null || imported.isAfter(at))) {
          at = imported;
        }
        if (!unknown && at == v.lastInspectionAt) continue;
        final due = at == null
            ? null
            : (at == v.lastInspectionAt && v.lastInspectionDueAt != null
                ? v.lastInspectionDueAt
                : inspectionDueFor(
                    expiry: v.inspectionExpiry, inspectedAt: at));
        vehicleUpdates.putIfAbsent(v.id, () => {}).addAll({
          'lastInspectionAt': at == null ? null : Timestamp.fromDate(at),
          'lastInspectionDueAt': due == null ? null : Timestamp.fromDate(due),
        });
      }
      for (final e in vehicleUpdates.entries) {
        writes.add((_vehicles(shopId).doc(e.key), e.value));
      }

      // 顧客の要約値
      final byCustomerNow = <String, List<LedgerVehicle>>{};
      for (final v in vehicles.values) {
        byCustomerNow.putIfAbsent(v.customerId, () => []).add(v);
      }
      for (final cid in touchedCustomers) {
        final summary = LedgerCustomerSummary.of(
          byCustomerNow[cid] ?? const [],
          today: _now(),
        );
        writes.add((
          _customers(shopId).doc(cid),
          {
            'vehicleCount': summary.vehicleCount,
            'nextInspectionAt': summary.nextInspectionAt == null
                ? null
                : Timestamp.fromDate(summary.nextInspectionAt!),
            'lastVisitAt': summary.lastVisitAt == null
                ? null
                : Timestamp.fromDate(summary.lastVisitAt!),
            'updatedAt': now,
          },
        ));
      }

      onProgress?.call(0, writes.length);
      for (var i = 0; i < writes.length; i += _batchLimit) {
        final batch = _firestore.batch();
        for (final (ref, data) in writes.skip(i).take(_batchLimit)) {
          batch.set(ref, data, SetOptions(merge: true));
        }
        await batch.commit();
        onProgress?.call(
            (i + _batchLimit).clamp(0, writes.length), writes.length);
      }

      return Result.success(LedgerHistoryResult(
        records: recordIds.length,
        problems: problems,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // 書き出し（2026-09-29 プロダクト評価 #8・#2）
  // ---------------------------------------------------------------------------

  /// 台帳の全件（顧客と車両）。CSV にするのは `buildLedgerCsv`。
  ///
  /// **やめるときに名簿を持ち出せる**ための読み取り。顧客と車両を1回ずつ
  /// 全件読む（取込と同じ）。4,000人の店で、読み取りは1万件ほどになる。
  Future<Result<LedgerExportData, AppError>> exportAll({
    required String shopId,
  }) async {
    try {
      final results = await Future.wait([
        _customers(shopId).get(),
        _vehicles(shopId).get(),
      ]);
      return Result.success(LedgerExportData(
        customers: results[0]
            .docs
            .map((d) => LedgerCustomer.fromMap(d.id, d.data()))
            .toList(),
        vehicles: results[1]
            .docs
            .map((d) => LedgerVehicle.fromMap(d.id, d.data()))
            .toList(),
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 車検案内（はがき・DM）の宛名。満了日が [from]〜[to]（両端の日を含む）の車。
  ///
  /// - [excludeNoticed]: いまの満了日について案内済みの車は除く（二度出さない）
  /// - [excludeLinked]: アプリを使っている客は除く（アプリに案内が届く）
  /// - **住所の無い客は除く**（はがきが出せない）。除いた台数は返す
  ///
  /// 顧客は、対象の車の持ち主だけを1件ずつ読む。
  Future<Result<InspectionNoticeList, AppError>> inspectionNoticeTargets({
    required String shopId,
    required DateTime from,
    required DateTime to,
    bool excludeNoticed = true,
    bool excludeLinked = true,
  }) async {
    try {
      final candidates = await _noticeCandidates(shopId, from, to);
      if (candidates == null) {
        return const Result.success(InspectionNoticeList.empty);
      }
      final (vehicles, customers) = candidates;

      final targets = <InspectionNoticeTarget>[];
      var noticed = 0;
      var linked = 0;
      var withoutAddress = 0;
      for (final v in vehicles) {
        final c = customers[v.customerId];
        if (c == null) continue; // 持ち主のいない車には出せない
        if (excludeNoticed && v.isNoticedForCurrentExpiry) {
          noticed++;
          continue;
        }
        if (excludeLinked && c.isLinked) {
          linked++;
          continue;
        }
        if ((c.address ?? '').trim().isEmpty) {
          withoutAddress++;
          continue;
        }
        targets.add(InspectionNoticeTarget(customer: c, vehicle: v));
      }
      return Result.success(InspectionNoticeList(
        targets: targets,
        alreadyNoticed: noticed,
        linked: linked,
        withoutAddress: withoutAddress,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// アプリに車検案内（プッシュ）を送れる車。満了日が [from]〜[to]（両端の日を含む）で、
  /// 持ち主がアプリとつながっている（[LedgerCustomer.isLinked]）車だけ。
  ///
  /// はがき（[inspectionNoticeTargets]）と同じ期間・同じ「案内済み」の判定を使う。
  /// 住所は要らない。いまの満了日で案内済みの車は**いつも**除く（アプリへの
  /// 二重送信はサーバー側でも止めるが、先に数を見せるため）。
  ///
  /// 利用者が通知を切っているか・端末が登録されているかは、店からは見えない
  /// （users は本人しか読めない）。そこは送ったあとの結果で分かる。
  Future<Result<InspectionNoticeList, AppError>> appInspectionNoticeTargets({
    required String shopId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final candidates = await _noticeCandidates(shopId, from, to);
      if (candidates == null) {
        return const Result.success(InspectionNoticeList.empty);
      }
      final (vehicles, customers) = candidates;

      final targets = <InspectionNoticeTarget>[];
      var noticed = 0;
      var notLinked = 0;
      for (final v in vehicles) {
        final c = customers[v.customerId];
        if (c == null) continue; // 持ち主のいない車には出せない
        if (v.isNoticedForCurrentExpiry) {
          noticed++;
          continue;
        }
        if (!c.isLinked) {
          notLinked++;
          continue;
        }
        targets.add(InspectionNoticeTarget(customer: c, vehicle: v));
      }
      return Result.success(InspectionNoticeList(
        targets: targets,
        alreadyNoticed: noticed,
        notLinked: notLinked,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 満了日が [from]〜[to]（両端の日を含む）の車（近い順）と、その持ち主。
  /// 期間が空なら null。顧客は、対象の車の持ち主だけを1件ずつ読む。
  Future<(List<LedgerVehicle>, Map<String, LedgerCustomer>)?> _noticeCandidates(
      String shopId, DateTime from, DateTime to) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day + 1);
    if (!end.isAfter(start)) return null;

    final snap = await _vehicles(shopId)
        .where('inspectionExpiry',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('inspectionExpiry', isLessThan: Timestamp.fromDate(end))
        .orderBy('inspectionExpiry')
        .get();
    final vehicles =
        snap.docs.map((d) => LedgerVehicle.fromMap(d.id, d.data())).toList();

    final ids = vehicles.map((v) => v.customerId).toSet().toList();
    final docs =
        await Future.wait(ids.map((id) => _customers(shopId).doc(id).get()));
    final customers = <String, LedgerCustomer>{
      for (final d in docs)
        if (d.exists && d.data() != null)
          d.id: LedgerCustomer.fromMap(d.id, d.data()!),
    };
    return (vehicles, customers);
  }

  /// 車検の案内を出した（宛名を書き出した）ことを、車ごとに記録する。
  ///
  /// 案内した日と、そのときの満了日を書く。満了日が進めば、次の案内の
  /// 対象に戻る。書いた台数を返す。消された車があれば失敗する
  /// （その回のバッチは書かれない）。
  Future<Result<int, AppError>> markInspectionNoticed({
    required String shopId,
    required List<LedgerVehicle> vehicles,
  }) async {
    if (vehicles.isEmpty) return const Result.success(0);
    try {
      final now = Timestamp.fromDate(_now());
      for (var i = 0; i < vehicles.length; i += _batchLimit) {
        final batch = _firestore.batch();
        for (final v in vehicles.skip(i).take(_batchLimit)) {
          batch.update(_vehicles(shopId).doc(v.id), {
            'inspectionNoticeAt': now,
            'inspectionNoticeExpiry': v.inspectionExpiry == null
                ? null
                : Timestamp.fromDate(v.inspectionExpiry!),
          });
        }
        await batch.commit();
      }
      return Result.success(vehicles.length);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // 取りこぼし（2026-09-29 プロダクト評価 #1）
  // ---------------------------------------------------------------------------

  /// 車検の入庫とみなす整備履歴の種類（整備管理ソフトの作業区分の言い方）。
  static bool isInspectionWork(String type) {
    final t = LedgerSearch.nameKey(type);
    return t.contains('車検') ||
        t.contains('継続検査') ||
        t.contains('carinspection');
  }

  /// 取りこぼしの集計。
  ///
  /// - 対象: 満了日が直近 [months] か月のうちに来た車
  /// - 入庫済み: 満了日の [leadDays] 日前から今日までに、車検の整備履歴がある
  /// - 取りこぼし: それが無い
  ///
  /// **整備履歴（伝票）は読まない**（2026-10-09）。4,000人・伝票1.5万件の店で
  /// 直近の伝票を全部読んでいたため、開くのに約30秒かかっていた。代わりに、
  /// 取込のときに車へ写しておいた「最後の車検日」（lastInspectionAt）と
  /// 「それがどの満了日の分か」（lastInspectionDueAt）を使う:
  ///
  /// 1. 満了日がこの期間に過ぎた車（＝名簿の満了日がまだ進んでいない車）を
  ///    読む。取りこぼした車の一覧はここから作る（声をかける相手なので
  ///    中身が要る）
  /// 2. 満了日が進んだ車（車検で入庫し、名簿を取り直した車）は、
  ///    lastInspectionDueAt の月ごとの count() で数える。中身は読まない
  ///
  /// 読み取りは「満了日が過ぎた車」の件数＋月の数の集計＋2件。
  ///
  /// 以前は、名簿を取り直して満了日が2年先へ進んだ車が分母からも分子からも
  /// 抜けていたため、取りこぼし率がほぼ 100% になっていた（2026-10-08
  /// 使用感テスト「39 / 39台」）。2. でその車を元の月に戻している。
  ///
  /// lastInspectionAt の無い車（2026-10-09 より前のデータで、まだ整備履歴を
  /// 取り込み直していない車）だけは、その車の伝票を読んで判定する。
  ///
  /// 最後に整備履歴を取り込んだのが [staleDays] 日より前（または一度も
  /// 無い）なら [LossReport.isStale] を立てる。取込が止まっていると、
  /// 入庫したのに記録が無い車が取りこぼしに見えるため、画面は率を出さない。
  Future<Result<LossReport, AppError>> lossReport({
    required String shopId,
    int months = 12,
    int leadDays = 60,
    int staleDays = 30,
  }) async {
    if (shopId.isEmpty) {
      return const Result.failure(AppError.validation('店が選ばれていません'));
    }
    if (months <= 0 || leadDays < 0) {
      return const Result.failure(AppError.validation('期間の指定が正しくありません'));
    }
    try {
      final now = _now();
      final today = DateTime(now.year, now.month, now.day);
      final from = DateTime(today.year, today.month - months + 1, 1);

      final byMonth = <String, LossMonth>{};
      for (var i = 0; i < months; i++) {
        final m = DateTime(from.year, from.month + i, 1);
        byMonth[_monthKey(m)] = LossMonth(month: m);
      }

      // 1. Cars whose (current) expiry passed in the period.
      final expiredSnap = await _vehicles(shopId)
          .where('inspectionExpiry',
              isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('inspectionExpiry', isLessThan: Timestamp.fromDate(today))
          .get();
      final expired = <LedgerVehicle>[];
      final unknown = <String>{};
      for (final d in expiredSnap.docs) {
        expired.add(LedgerVehicle.fromMap(d.id, d.data()));
        if (!d.data().containsKey('lastInspectionAt')) unknown.add(d.id);
      }
      final legacy = await _latestInspections(shopId, unknown);

      // 2. Inspections at this shop per due month. Cars that are still in
      //    step 1 are subtracted so nothing is counted twice.
      final dueCounts = await Future.wait([
        for (final m in byMonth.values)
          _vehicles(shopId)
              .where('lastInspectionDueAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(m.month))
              .where('lastInspectionDueAt',
                  isLessThan: Timestamp.fromDate(_minDate(
                      DateTime(m.month.year, m.month.month + 1, 1), today)))
              .count()
              .get()
              .then((s) => s.count ?? 0),
      ]);
      for (final (i, m) in byMonth.values.indexed) {
        m.returned += dueCounts[i];
      }

      final lost = <LedgerVehicle>[];
      for (final v in expired) {
        final due = v.lastInspectionDueAt;
        if (due != null) byMonth[_monthKey(due)]?.returned--;

        final expiry = v.inspectionExpiry!;
        final month = byMonth[_monthKey(expiry)];
        if (month == null) continue;
        final last = unknown.contains(v.id) ? legacy[v.id] : v.lastInspectionAt;
        final windowStart = expiry.subtract(Duration(days: leadDays));
        if (last != null && !last.isBefore(windowStart)) {
          month.returned++;
        } else {
          month.lost++;
          lost.add(v);
        }
      }
      for (final m in byMonth.values) {
        if (m.returned < 0) m.returned = 0;
      }
      lost.sort((a, b) => b.inspectionExpiry!.compareTo(a.inspectionExpiry!));

      final lastImportAt = await _lastImportAt(shopId, now);
      final stale = lastImportAt == null ||
          today.difference(lastImportAt).inDays > staleDays;
      return Result.success(LossReport(
        months: byMonth.values.toList(),
        lostVehicles: lost,
        lastImportAt: lastImportAt,
        isStale: stale,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// When the service records were last brought in.
  ///
  /// The newest `updatedAt` (written by the import), and the newest work
  /// `date` as a lower bound: a record without `updatedAt` (entered by
  /// other means) still shows that the records are being kept. Values of
  /// an unexpected type (string, number) are read as dates rather than
  /// failing the whole report.
  Future<DateTime?> _lastImportAt(String shopId, DateTime now) async {
    final results = await Future.wait([
      _records(shopId).orderBy('updatedAt', descending: true).limit(1).get(),
      _records(shopId).orderBy('date', descending: true).limit(1).get(),
    ]);
    final updatedAt = results[0].docs.isEmpty
        ? null
        : anyDate(results[0].docs.first.data()['updatedAt']);
    var workDate = results[1].docs.isEmpty
        ? null
        : anyDate(results[1].docs.first.data()['date']);
    // A mistyped future work date must not make stale data look fresh.
    if (workDate != null && workDate.isAfter(now)) workDate = null;
    if (updatedAt == null) return workDate;
    if (workDate == null) return updatedAt;
    return updatedAt.isAfter(workDate) ? updatedAt : workDate;
  }

  /// Reads a date stored as a Timestamp, DateTime, epoch milliseconds or
  /// an ISO-8601 string. Anything else is null.
  static DateTime? anyDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.tryParse(v)?.toLocal();
    return null;
  }

  /// The expiry an inspection on [inspectedAt] was for.
  ///
  /// The roster may already carry the next expiry (one or two years
  /// later) when the records are imported, so step back whole years until
  /// the date falls just after the inspection (inspections are done up to
  /// about two months before the expiry). Null when nothing fits (for
  /// example, no expiry on the roster).
  static DateTime? inspectionDueFor({
    required DateTime? expiry,
    required DateTime inspectedAt,
  }) {
    if (expiry == null) return null;
    final earliest = inspectedAt.subtract(const Duration(days: 31));
    final latest = inspectedAt.add(const Duration(days: 92));
    for (var years = 0; years <= 3; years++) {
      final due = DateTime(expiry.year - years, expiry.month, expiry.day);
      if (!due.isBefore(earliest) && !due.isAfter(latest)) return due;
    }
    return null;
  }

  /// Above this many vehicles, read all records once instead of asking
  /// per vehicle (one query per 30 vehicles).
  static const int _readAllRecordsAbove = 300;

  /// The latest inspection date per vehicle, from the stored records.
  /// Only used for vehicles without `lastInspectionAt` (older data).
  Future<Map<String, DateTime>> _latestInspections(
    String shopId,
    Set<String> vehicleIds, {
    bool readAll = false,
  }) async {
    final latest = <String, DateTime>{};
    if (vehicleIds.isEmpty) return latest;
    void take(QueryDocumentSnapshot<Map<String, dynamic>> d) {
      final m = d.data();
      final vid = m['customerVehicleId'] as String?;
      final date = anyDate(m['date']);
      if (vid == null || date == null || !vehicleIds.contains(vid)) return;
      if (!isInspectionWork(m['type'] as String? ?? '')) return;
      final seen = latest[vid];
      if (seen == null || date.isAfter(seen)) latest[vid] = date;
    }

    if (readAll) {
      (await _records(shopId).get()).docs.forEach(take);
      return latest;
    }
    final ids = vehicleIds.toList();
    final snaps = await Future.wait([
      for (var i = 0; i < ids.length; i += 30)
        _records(shopId)
            .where('customerVehicleId',
                whereIn: ids.sublist(i, (i + 30).clamp(0, ids.length)))
            .get(),
    ]);
    for (final s in snaps) {
      s.docs.forEach(take);
    }
    return latest;
  }

  static DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  static String _monthKey(DateTime d) => '${d.year}-${d.month}';

  // ---------------------------------------------------------------------------
  // 統計への協力
  // ---------------------------------------------------------------------------

  /// 整備実績を、車種別の維持費レポートの匿名の集計に使ってよいか。
  Future<Result<bool, AppError>> allowsStatistics(String shopId) async {
    try {
      final doc = await _firestore.collection('shops').doc(shopId).get();
      return Result.success(doc.data()?['allowsStatistics'] == true);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 同意を切り替える。**書けるのは店主だけ**（shops のルール）。
  Future<Result<void, AppError>> setAllowsStatistics({
    required String shopId,
    required bool value,
  }) async {
    try {
      await _firestore.collection('shops').doc(shopId).update({
        'allowsStatistics': value,
        'allowsStatisticsUpdatedAt': Timestamp.fromDate(_now()),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  /// 名前の入力チェック。画面とサービスで同じ文言を出すために公開している。
  static String? validateName(String? name) {
    final t = name?.trim() ?? '';
    if (t.isEmpty) return '名前を入力してください';
    if (t.length > 100) return '名前は100文字以内で入力してください';
    return null;
  }

  Future<void> _renameVehicles(
    String shopId,
    String customerId,
    String name,
  ) async {
    final snap = await _vehicles(shopId)
        .where('customerId', isEqualTo: customerId)
        .get();
    for (var i = 0; i < snap.docs.length; i += _batchLimit) {
      final batch = _firestore.batch();
      for (final d in snap.docs.skip(i).take(_batchLimit)) {
        batch.update(d.reference, {'customerName': name});
      }
      await batch.commit();
    }
  }

  static int _byInspection(LedgerVehicle a, LedgerVehicle b) {
    final x = a.inspectionExpiry;
    final y = b.inspectionExpiry;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  }

  /// [limit] より1件多く読んで、続きがあるかを判定する。
  Future<LedgerPage<T>> _page<T>(
    Query<Map<String, dynamic>> q, {
    required Object? cursor,
    required int limit,
    required T Function(String id, Map<String, dynamic> data) map,
  }) async {
    var query = q;
    if (cursor is DocumentSnapshot) {
      query = query.startAfterDocument(cursor);
    }
    final snap = await query.limit(limit + 1).get();
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    return LedgerPage(
      items: pageDocs.map((d) => map(d.id, d.data())).toList(),
      cursor: pageDocs.isEmpty ? cursor : pageDocs.last,
      hasMore: hasMore,
    );
  }
}

/// 取込の結果。
class LedgerImportResult {
  final int createdCustomers;
  final int updatedCustomers;
  final int vehicles;

  const LedgerImportResult({
    required this.createdCustomers,
    required this.updatedCustomers,
    required this.vehicles,
  });
}

/// 台帳の全件（書き出し用）。
class LedgerExportData {
  final List<LedgerCustomer> customers;
  final List<LedgerVehicle> vehicles;

  const LedgerExportData({required this.customers, required this.vehicles});
}

/// 車検案内の宛名と、除いた車の台数（画面で「なぜ少ないか」を見せるため）。
class InspectionNoticeList {
  final List<InspectionNoticeTarget> targets;

  /// いまの満了日について、もう案内を出した車。
  final int alreadyNoticed;

  /// アプリを使っている客の車。
  final int linked;

  /// 住所の無い客の車。
  final int withoutAddress;

  /// アプリとつながっていない客の車（アプリへの案内のとき）。
  final int notLinked;

  const InspectionNoticeList({
    required this.targets,
    this.alreadyNoticed = 0,
    this.linked = 0,
    this.withoutAddress = 0,
    this.notLinked = 0,
  });

  static const empty = InspectionNoticeList(targets: []);
}

/// 整備履歴の取込の結果。
class LedgerHistoryResult {
  /// 書き込んだ伝票の件数。
  final int records;

  /// 台帳の車と突き合わせられなかった行。
  final List<LedgerImportProblem> problems;

  const LedgerHistoryResult({required this.records, required this.problems});
}

/// 満了した月ひとつぶんの取りこぼし。
class LossMonth {
  final DateTime month;
  int returned = 0;
  int lost = 0;

  LossMonth({required this.month});

  int get expired => returned + lost;

  /// 取りこぼし率（0〜1）。満了した車が無ければ null。
  double? get rate => expired == 0 ? null : lost / expired;
}

/// 取りこぼしの集計結果。
class LossReport {
  final List<LossMonth> months;

  /// 取りこぼした車（満了日の新しい順）。声をかける相手。
  final List<LedgerVehicle> lostVehicles;
  final DateTime? lastImportAt;

  /// 整備履歴の取込が古い（または一度も無い）。率を出さない。
  final bool isStale;

  const LossReport({
    required this.months,
    required this.lostVehicles,
    required this.lastImportAt,
    required this.isStale,
  });

  int get expired => months.fold(0, (a, m) => a + m.expired);
  int get lost => months.fold(0, (a, m) => a + m.lost);
  double? get rate => expired == 0 ? null : lost / expired;
}
