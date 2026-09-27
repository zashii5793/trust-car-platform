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
  /// [search] があれば、並べ方は無視してフリガナの前方一致で引く
  /// （Firestore では範囲条件と別フィールドの並べ替えを組み合わせられない）。
  Future<Result<LedgerPage<LedgerCustomer>, AppError>> listCustomers({
    required String shopId,
    LedgerCustomerSort sort = LedgerCustomerSort.kana,
    String? search,
    Object? cursor,
    int limit = pageSize,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _customers(shopId);
      final key = search == null ? '' : LedgerSearch.nameKey(search);

      if (key.isNotEmpty) {
        q = q
            .where('searchKey', isGreaterThanOrEqualTo: key)
            .where('searchKey', isLessThan: '$key${LedgerSearch.rangeEnd}')
            .orderBy('searchKey');
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

  /// ナンバー末尾の番号（「12-34」→ "1234"）で車両を引く。
  Future<Result<List<LedgerVehicle>, AppError>> findVehiclesByPlateNumber({
    required String shopId,
    required String number,
  }) async {
    final key = LedgerSearch.plateNumber(number);
    if (key == null) return const Result.success([]);
    try {
      final snap = await _vehicles(shopId)
          .where('plateNumber', isEqualTo: key)
          .limit(pageSize)
          .get();
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
      final createdAt = existing.exists
          ? LedgerVehicle.fromMap(ref.id, existing.data()!).createdAt
          : now;

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
        createdAt: createdAt,
        updatedAt: now,
      );
      await ref.set(vehicle.toMap());
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
        final cid = idForExternal('c', c.stableExternalId);
        final isNew = !existingCustomers.containsKey(cid);
        isNew ? created++ : updated++;

        // この顧客の車両: 既にあるもの（取込で上書きされないもの）＋今回の分
        final vehicles = vehiclesByCustomer.putIfAbsent(cid, () => {});
        for (final iv in c.vehicles) {
          final vid = idForExternal('v', iv.stableExternalId(c.key));
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
            externalId: iv.externalId ?? iv.stableExternalId(c.key),
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
          createdAt: now,
          updatedAt: now,
        );
        final data = <String, dynamic>{
          'kind': c.kind.name,
          'name': c.name,
          'nameKana': c.nameKana,
          'searchKey': probe.searchKey,
          'contactPerson': c.contactPerson,
          'phone': c.phone,
          'email': c.email,
          'postalCode': c.postalCode,
          'address': c.address,
          'externalId': c.stableExternalId,
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
      final vehicles = <String, LedgerVehicle>{
        for (final d in (await _vehicles(shopId).get()).docs)
          d.id: LedgerVehicle.fromMap(d.id, d.data()),
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
      }

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
        writes.add((
          _vehicles(shopId).doc(v.id),
          {
            'lastVisitAt': Timestamp.fromDate(row.date),
            if (row.mileage != null) 'lastMileage': row.mileage,
            'updatedAt': now,
          },
        ));
        touchedCustomers.add(v.customerId);
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

/// 整備履歴の取込の結果。
class LedgerHistoryResult {
  /// 書き込んだ伝票の件数。
  final int records;

  /// 台帳の車と突き合わせられなかった行。
  final List<LedgerImportProblem> problems;

  const LedgerHistoryResult({required this.records, required this.problems});
}
