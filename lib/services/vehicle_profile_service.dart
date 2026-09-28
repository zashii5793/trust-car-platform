import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/accessory_showcase.dart';
import '../models/drive_log.dart';
import '../models/maintenance_record.dart';
import '../models/post.dart';
import '../models/vehicle.dart';
import '../models/vehicle_profile.dart';

/// 愛車ページに集めるもの。
class VehicleProfileContents {
  final List<Post> posts;
  final List<AccessoryShowcase> showcases;
  final List<DriveLog> driveLogs;

  const VehicleProfileContents({
    this.posts = const [],
    this.showcases = const [],
    this.driveLogs = const [],
  });

  bool get isEmpty => posts.isEmpty && showcases.isEmpty && driveLogs.isEmpty;
}

/// 愛車ページ（`vehicle_profiles/{vehicleId}`）の読み書き。
///
/// 車を主役にして、その車の投稿・パーツ・公開ドライブを1か所に集める。
/// 集めるのは**もともと公開されているものだけ**（公開の投稿・パーツの
/// レビュー・公開にしたドライブ）。非公開のものを、ここで開けることはしない。
class VehicleProfileService {
  final FirebaseFirestore _firestore;
  final DateTime Function() _now;

  VehicleProfileService({
    required FirebaseFirestore firestore,
    DateTime Function()? now,
  })  : _firestore = firestore,
        _now = now ?? DateTime.now;

  static const String collection = 'vehicle_profiles';
  static const int _limit = 20;

  DocumentReference<Map<String, dynamic>> _doc(String vehicleId) =>
      _firestore.collection(collection).doc(vehicleId);

  /// 愛車ページ。無ければ null。公開していないページは本人以外には
  /// 読めない（ルールで拒否され、失敗として返る）。
  Future<Result<VehicleProfile?, AppError>> get(String vehicleId) async {
    if (vehicleId.isEmpty) return const Result.success(null);
    try {
      final doc = await _doc(vehicleId).get();
      final data = doc.data();
      if (!doc.exists || data == null) return const Result.success(null);
      return Result.success(VehicleProfile.fromMap(data));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 本人が愛車ページを作る・直す。
  ///
  /// 車の情報は、その時点の車両から写す（車種・年式・グレードだけ）。
  /// 整備を出すなら、その時点の記録から種類と回数を数えて写す。
  Future<Result<VehicleProfile, AppError>> save({
    required String ownerId,
    required String ownerName,
    required Vehicle vehicle,
    required bool isPublic,
    required bool showsMaintenance,
    List<MaintenanceRecord> records = const [],
    String? nickname,
    String? bio,
  }) async {
    if (vehicle.userId != ownerId) {
      return const Result.failure(AppError.permission('自分の車だけ公開できます'));
    }
    String? trimmed(String? v, int max) {
      final t = v?.trim();
      if (t == null || t.isEmpty) return null;
      return t.length > max ? t.substring(0, max) : t;
    }

    final profile = VehicleProfile(
      vehicleId: vehicle.id,
      ownerId: ownerId,
      ownerName: trimmed(ownerName, 50) ?? 'オーナー',
      maker: vehicle.maker,
      model: vehicle.model,
      year: vehicle.year == 0 ? null : vehicle.year,
      grade: trimmed(vehicle.grade, 50),
      nickname: trimmed(nickname, 30),
      bio: trimmed(bio, 300),
      imageUrl: vehicle.imageUrl,
      isPublic: isPublic,
      showsMaintenance: showsMaintenance,
      maintenance: showsMaintenance
          ? MaintenanceTally.fromRecords(
              records.where((r) => r.vehicleId == vehicle.id).toList())
          : const [],
      updatedAt: _now(),
    );
    try {
      await _doc(vehicle.id).set(profile.toMap());
      return Result.success(profile);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// ページに集める中身。それぞれ、もともと公開されているものだけを読む。
  ///
  /// 1つが読めなくても、他は出す（投稿だけ読めない、で空のページにしない）。
  Future<VehicleProfileContents> contents(VehicleProfile profile) async {
    final results = await Future.wait([
      _posts(profile),
      _showcases(profile),
      _driveLogs(profile),
    ]);
    return VehicleProfileContents(
      posts: results[0] as List<Post>,
      showcases: results[1] as List<AccessoryShowcase>,
      driveLogs: results[2] as List<DriveLog>,
    );
  }

  Future<List<Post>> _posts(VehicleProfile p) async {
    try {
      final snap = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: p.ownerId)
          .where('vehicleTag.vehicleId', isEqualTo: p.vehicleId)
          .where('visibility', isEqualTo: PostVisibility.public.storageName)
          .orderBy('createdAt', descending: true)
          .limit(_limit)
          .get();
      return _each(snap.docs, Post.fromFirestore);
    } catch (_) {
      return const [];
    }
  }

  Future<List<AccessoryShowcase>> _showcases(VehicleProfile p) async {
    try {
      final snap = await _firestore
          .collection('accessory_showcases')
          .where('userId', isEqualTo: p.ownerId)
          .where('vehicleId', isEqualTo: p.vehicleId)
          .limit(_limit)
          .get();
      return _each(snap.docs, AccessoryShowcase.fromFirestore)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return const [];
    }
  }

  Future<List<DriveLog>> _driveLogs(VehicleProfile p) async {
    try {
      final snap = await _firestore
          .collection('drive_logs')
          .where('userId', isEqualTo: p.ownerId)
          .where('vehicleId', isEqualTo: p.vehicleId)
          .where('isPublic', isEqualTo: true)
          .limit(_limit)
          .get();
      return _each(snap.docs, (d) => DriveLog.fromMap(d.data(), d.id))
        ..sort((a, b) => b.startTime.compareTo(a.startTime));
    } catch (_) {
      return const [];
    }
  }

  /// 1件ずつ読み、読めないものだけ飛ばす。**壊れた1件で一覧全体を
  /// 空にしない。**
  static List<T> _each<T>(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    T Function(QueryDocumentSnapshot<Map<String, dynamic>> d) read,
  ) {
    final out = <T>[];
    for (final d in docs) {
      try {
        out.add(read(d));
      } catch (_) {
        // 古い形式・書きかけのドキュメント
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // フォロー・同じ車種
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _follows =>
      _firestore.collection('vehicle_follows');

  static String _followId(String uid, String vehicleId) => '${uid}_$vehicleId';

  Future<Result<void, AppError>> follow({
    required String uid,
    required VehicleProfile profile,
  }) async {
    if (uid == profile.ownerId) {
      return const Result.failure(AppError.validation('自分の車はフォローできません'));
    }
    try {
      await _follows.doc(_followId(uid, profile.vehicleId)).set({
        'uid': uid,
        'vehicleId': profile.vehicleId,
        'ownerId': profile.ownerId,
        'createdAt': Timestamp.fromDate(_now()),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  Future<Result<void, AppError>> unfollow({
    required String uid,
    required String vehicleId,
  }) async {
    try {
      await _follows.doc(_followId(uid, vehicleId)).delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  Future<bool> isFollowing({
    required String uid,
    required String vehicleId,
  }) async {
    try {
      return (await _follows.doc(_followId(uid, vehicleId)).get()).exists;
    } catch (_) {
      return false;
    }
  }

  /// フォロワーの人数。**数えるだけで、全員分は読まない。**
  Future<int> followerCount(String vehicleId) async {
    try {
      final agg =
          await _follows.where('vehicleId', isEqualTo: vehicleId).count().get();
      return agg.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 同じ車種の、公開している愛車ページ（自分のページは除く）。
  Future<List<VehicleProfile>> sameModel(VehicleProfile p,
      {int limit = 20}) async {
    try {
      final data = p.toMap();
      final snap = await _firestore
          .collection(collection)
          .where('isPublic', isEqualTo: true)
          .where('makerKey', isEqualTo: data['makerKey'])
          .where('modelKey', isEqualTo: data['modelKey'])
          .limit(limit + 1)
          .get();
      return _each(snap.docs, (d) => VehicleProfile.fromMap(d.data()))
          .where((x) => x.vehicleId != p.vehicleId)
          .take(limit)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// フォローしている愛車ページ（公開中のものだけ・新しくフォローした順）。
  Future<List<VehicleProfile>> followed(String uid, {int limit = 30}) async {
    try {
      final follows =
          await _follows.where('uid', isEqualTo: uid).limit(limit).get();
      final ids = follows.docs
          .map((d) => d.data()['vehicleId'] as String?)
          .whereType<String>()
          .toList();
      if (ids.isEmpty) return const [];
      final out = <VehicleProfile>[];
      // whereIn は30件まで
      for (var i = 0; i < ids.length; i += 30) {
        final chunk = ids.skip(i).take(30).toList();
        final snap = await _firestore
            .collection(collection)
            .where('isPublic', isEqualTo: true)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        out.addAll(_each(snap.docs, (d) => VehicleProfile.fromMap(d.data())));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
