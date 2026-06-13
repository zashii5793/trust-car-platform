import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/fleet_member.dart';

/// Service for managing fleet members and their roles.
///
/// Firestore collection: `fleet_members`
/// Document ID format:   `{companyId}_{userId}`
class FleetMemberService {
  final FirebaseFirestore _firestore;

  FleetMemberService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('fleet_members');

  String _docId(String companyId, String userId) => '${companyId}_$userId';

  // ──────────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────────

  Future<FleetMember?> _fetchMember(String companyId, String userId) async {
    final doc = await _col.doc(_docId(companyId, userId)).get();
    if (!doc.exists) {
      return null;
    }
    return FleetMember.fromFirestore(doc);
  }

  Future<FleetRole?> _fetchRole(String companyId, String userId) async {
    final member = await _fetchMember(companyId, userId);
    return member?.role;
  }

  // ──────────────────────────────────────────────
  // addMember
  // ──────────────────────────────────────────────

  /// Add a new member to the fleet. Only owners may perform this action.
  Future<Result<FleetMember, AppError>> addMember({
    required String companyId,
    required String userId,
    required FleetRole role,
    required String requesterId,
  }) async {
    if (companyId.isEmpty) {
      return const Result.failure(
        AppError.validation('companyId must not be empty', field: 'companyId'),
      );
    }
    if (userId.isEmpty) {
      return const Result.failure(
        AppError.validation('userId must not be empty', field: 'userId'),
      );
    }

    try {
      // Verify requester is an owner
      final requesterRole = await _fetchRole(companyId, requesterId);
      if (requesterRole != FleetRole.owner) {
        return const Result.failure(
          AppError.permission('Only owners can add members'),
        );
      }

      // Check for duplicate
      final existing = await _fetchMember(companyId, userId);
      if (existing != null) {
        return const Result.failure(
          AppError.validation('User is already a member of this fleet'),
        );
      }

      final now = DateTime.now();
      final docId = _docId(companyId, userId);
      final member = FleetMember(
        id: docId,
        companyId: companyId,
        userId: userId,
        role: role,
        joinedAt: now,
      );

      await _col.doc(docId).set(member.toMap());
      return Result.success(member);
    } catch (e, st) {
      return Result.failure(mapFirebaseError(e, stackTrace: st));
    }
  }

  // ──────────────────────────────────────────────
  // updateRole
  // ──────────────────────────────────────────────

  /// Update the role of an existing member. Only owners may perform this action.
  Future<Result<FleetMember, AppError>> updateRole({
    required String companyId,
    required String userId,
    required FleetRole newRole,
    required String requesterId,
  }) async {
    if (companyId.isEmpty) {
      return const Result.failure(
        AppError.validation('companyId must not be empty', field: 'companyId'),
      );
    }

    try {
      // Verify requester is an owner
      final requesterRole = await _fetchRole(companyId, requesterId);
      if (requesterRole != FleetRole.owner) {
        return const Result.failure(
          AppError.permission('Only owners can update member roles'),
        );
      }

      // Verify target member exists
      final target = await _fetchMember(companyId, userId);
      if (target == null) {
        return Result.failure(
          AppError.notFound(
            'Member not found: $userId',
            resourceType: 'FleetMember',
          ),
        );
      }

      final updated = target.copyWith(role: newRole);
      await _col.doc(_docId(companyId, userId)).update({'role': newRole.name});
      return Result.success(updated);
    } catch (e, st) {
      return Result.failure(mapFirebaseError(e, stackTrace: st));
    }
  }

  // ──────────────────────────────────────────────
  // removeMember
  // ──────────────────────────────────────────────

  /// Remove a member from the fleet.
  /// Allowed if requester is the owner OR the member themselves (self-leave).
  Future<Result<void, AppError>> removeMember({
    required String companyId,
    required String userId,
    required String requesterId,
  }) async {
    if (userId.isEmpty) {
      return const Result.failure(
        AppError.validation('userId must not be empty', field: 'userId'),
      );
    }

    try {
      // Verify target member exists
      final target = await _fetchMember(companyId, userId);
      if (target == null) {
        return Result.failure(
          AppError.notFound(
            'Member not found: $userId',
            resourceType: 'FleetMember',
          ),
        );
      }

      // Allow if requester is owner or self
      final isSelf = requesterId == userId;
      if (!isSelf) {
        final requesterRole = await _fetchRole(companyId, requesterId);
        if (requesterRole != FleetRole.owner) {
          return const Result.failure(
            AppError.permission(
              'Only owners or the member themselves can remove a member',
            ),
          );
        }
      }

      await _col.doc(_docId(companyId, userId)).delete();
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(mapFirebaseError(e, stackTrace: st));
    }
  }

  // ──────────────────────────────────────────────
  // getMembers
  // ──────────────────────────────────────────────

  /// Return all members belonging to [companyId].
  Future<Result<List<FleetMember>, AppError>> getMembers(
    String companyId,
  ) async {
    if (companyId.isEmpty) {
      return const Result.failure(
        AppError.validation('companyId must not be empty', field: 'companyId'),
      );
    }

    try {
      final snapshot = await _col
          .where('companyId', isEqualTo: companyId)
          .get();

      final members = snapshot.docs
          .map((doc) => FleetMember.fromFirestore(doc))
          .toList();
      return Result.success(members);
    } catch (e, st) {
      return Result.failure(mapFirebaseError(e, stackTrace: st));
    }
  }

  // ──────────────────────────────────────────────
  // getMemberRole
  // ──────────────────────────────────────────────

  /// Return the [FleetRole] of [userId] in [companyId], or null if not a member.
  Future<Result<FleetRole?, AppError>> getMemberRole({
    required String companyId,
    required String userId,
  }) async {
    if (companyId.isEmpty) {
      return const Result.failure(
        AppError.validation('companyId must not be empty', field: 'companyId'),
      );
    }
    if (userId.isEmpty) {
      return const Result.failure(
        AppError.validation('userId must not be empty', field: 'userId'),
      );
    }

    try {
      final role = await _fetchRole(companyId, userId);
      return Result.success(role);
    } catch (e, st) {
      return Result.failure(mapFirebaseError(e, stackTrace: st));
    }
  }

  // ──────────────────────────────────────────────
  // canWrite
  // ──────────────────────────────────────────────

  /// Returns true if [userId] has write permission in [companyId].
  /// owner and manager can write; staff and viewer cannot.
  /// Non-members also cannot write (returns false, not an error).
  Future<Result<bool, AppError>> canWrite({
    required String companyId,
    required String userId,
  }) async {
    if (companyId.isEmpty) {
      return const Result.failure(
        AppError.validation('companyId must not be empty', field: 'companyId'),
      );
    }

    try {
      final role = await _fetchRole(companyId, userId);
      final allowed =
          role == FleetRole.owner || role == FleetRole.manager;
      return Result.success(allowed);
    } catch (e, st) {
      return Result.failure(mapFirebaseError(e, stackTrace: st));
    }
  }
}
