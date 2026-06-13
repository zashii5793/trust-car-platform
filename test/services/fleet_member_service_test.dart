import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:trust_car_platform/models/fleet_member.dart';
import 'package:trust_car_platform/services/fleet_member_service.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FleetMemberService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = FleetMemberService(firestore: fakeFirestore);
  });

  // Helper: seed an owner member
  Future<void> seedOwner({
    required String companyId,
    required String userId,
  }) async {
    final docId = '${companyId}_$userId';
    await fakeFirestore.collection('fleet_members').doc(docId).set({
      'companyId': companyId,
      'userId': userId,
      'role': 'owner',
      'displayName': 'Owner User',
      'joinedAt': DateTime(2024, 1, 1).toIso8601String(),
    });
  }

  // Helper: seed a member with arbitrary role
  Future<void> seedMember({
    required String companyId,
    required String userId,
    required FleetRole role,
    String? displayName,
  }) async {
    final docId = '${companyId}_$userId';
    await fakeFirestore.collection('fleet_members').doc(docId).set({
      'companyId': companyId,
      'userId': userId,
      'role': role.name,
      'displayName': displayName ?? 'Test User',
      'joinedAt': DateTime(2024, 1, 1).toIso8601String(),
    });
  }

  // ──────────────────────────────────────────────
  // addMember
  // ──────────────────────────────────────────────
  group('addMember', () {
    test('owner can add a manager member', () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');

      final result = await service.addMember(
        companyId: 'company1',
        userId: 'newUser1',
        role: FleetRole.manager,
        requesterId: 'owner1',
      );

      expect(result.isSuccess, true);
      final added = result.valueOrNull!;
      expect(added.userId, 'newUser1');
      expect(added.role, FleetRole.manager);
      expect(added.companyId, 'company1');
    });

    test('owner can add a staff member', () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');

      final result = await service.addMember(
        companyId: 'company1',
        userId: 'staffUser',
        role: FleetRole.staff,
        requesterId: 'owner1',
      );

      expect(result.isSuccess, true);
      expect(result.valueOrNull!.role, FleetRole.staff);
    });

    test('non-owner (manager) cannot add member — returns permission error',
        () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');
      await seedMember(
        companyId: 'company1',
        userId: 'manager1',
        role: FleetRole.manager,
      );

      final result = await service.addMember(
        companyId: 'company1',
        userId: 'newUser',
        role: FleetRole.staff,
        requesterId: 'manager1',
      );

      expect(result.isFailure, true);
      expect(result.errorOrNull, isA<PermissionError>());
    });

    test('non-member requester cannot add member', () async {
      final result = await service.addMember(
        companyId: 'company1',
        userId: 'newUser',
        role: FleetRole.staff,
        requesterId: 'outsider',
      );

      expect(result.isFailure, true);
      expect(result.errorOrNull, isA<PermissionError>());
    });

    group('Edge Cases', () {
      test('empty companyId returns validation error', () async {
        final result = await service.addMember(
          companyId: '',
          userId: 'user1',
          role: FleetRole.staff,
          requesterId: 'owner1',
        );

        expect(result.isFailure, true);
        expect(result.errorOrNull, isA<ValidationError>());
      });

      test('empty userId returns validation error', () async {
        await seedOwner(companyId: 'company1', userId: 'owner1');

        final result = await service.addMember(
          companyId: 'company1',
          userId: '',
          role: FleetRole.staff,
          requesterId: 'owner1',
        );

        expect(result.isFailure, true);
        expect(result.errorOrNull, isA<ValidationError>());
      });

      test('adding duplicate member returns validation error', () async {
        await seedOwner(companyId: 'company1', userId: 'owner1');
        await seedMember(
          companyId: 'company1',
          userId: 'existingUser',
          role: FleetRole.staff,
        );

        final result = await service.addMember(
          companyId: 'company1',
          userId: 'existingUser',
          role: FleetRole.viewer,
          requesterId: 'owner1',
        );

        expect(result.isFailure, true);
        expect(result.errorOrNull, isA<ValidationError>());
      });
    });
  });

  // ──────────────────────────────────────────────
  // updateRole
  // ──────────────────────────────────────────────
  group('updateRole', () {
    test('owner can update manager to staff', () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');
      await seedMember(
        companyId: 'company1',
        userId: 'manager1',
        role: FleetRole.manager,
      );

      final result = await service.updateRole(
        companyId: 'company1',
        userId: 'manager1',
        newRole: FleetRole.staff,
        requesterId: 'owner1',
      );

      expect(result.isSuccess, true);
      expect(result.valueOrNull!.role, FleetRole.staff);
    });

    test('non-owner cannot update role — returns permission error', () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');
      await seedMember(
        companyId: 'company1',
        userId: 'manager1',
        role: FleetRole.manager,
      );
      await seedMember(
        companyId: 'company1',
        userId: 'staff1',
        role: FleetRole.staff,
      );

      final result = await service.updateRole(
        companyId: 'company1',
        userId: 'staff1',
        newRole: FleetRole.viewer,
        requesterId: 'manager1',
      );

      expect(result.isFailure, true);
      expect(result.errorOrNull, isA<PermissionError>());
    });

    test('updating role of non-existent member returns notFound error',
        () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');

      final result = await service.updateRole(
        companyId: 'company1',
        userId: 'ghostUser',
        newRole: FleetRole.staff,
        requesterId: 'owner1',
      );

      expect(result.isFailure, true);
      expect(result.errorOrNull, isA<NotFoundError>());
    });

    group('Edge Cases', () {
      test('empty companyId returns validation error', () async {
        final result = await service.updateRole(
          companyId: '',
          userId: 'user1',
          newRole: FleetRole.staff,
          requesterId: 'owner1',
        );

        expect(result.isFailure, true);
        expect(result.errorOrNull, isA<ValidationError>());
      });
    });
  });

  // ──────────────────────────────────────────────
  // removeMember
  // ──────────────────────────────────────────────
  group('removeMember', () {
    test('owner can remove a staff member', () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');
      await seedMember(
        companyId: 'company1',
        userId: 'staff1',
        role: FleetRole.staff,
      );

      final result = await service.removeMember(
        companyId: 'company1',
        userId: 'staff1',
        requesterId: 'owner1',
      );

      expect(result.isSuccess, true);
    });

    test('member can remove themselves (self-leave)', () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');
      await seedMember(
        companyId: 'company1',
        userId: 'staff1',
        role: FleetRole.staff,
      );

      final result = await service.removeMember(
        companyId: 'company1',
        userId: 'staff1',
        requesterId: 'staff1',
      );

      expect(result.isSuccess, true);
    });

    test('non-owner cannot remove other member', () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');
      await seedMember(
        companyId: 'company1',
        userId: 'manager1',
        role: FleetRole.manager,
      );
      await seedMember(
        companyId: 'company1',
        userId: 'staff1',
        role: FleetRole.staff,
      );

      final result = await service.removeMember(
        companyId: 'company1',
        userId: 'staff1',
        requesterId: 'manager1',
      );

      expect(result.isFailure, true);
      expect(result.errorOrNull, isA<PermissionError>());
    });

    test('removing non-existent member returns notFound error', () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');

      final result = await service.removeMember(
        companyId: 'company1',
        userId: 'ghostUser',
        requesterId: 'owner1',
      );

      expect(result.isFailure, true);
      expect(result.errorOrNull, isA<NotFoundError>());
    });

    group('Edge Cases', () {
      test('empty userId returns validation error', () async {
        final result = await service.removeMember(
          companyId: 'company1',
          userId: '',
          requesterId: 'owner1',
        );

        expect(result.isFailure, true);
        expect(result.errorOrNull, isA<ValidationError>());
      });
    });
  });

  // ──────────────────────────────────────────────
  // getMembers
  // ──────────────────────────────────────────────
  group('getMembers', () {
    test('returns all members for a company', () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');
      await seedMember(
        companyId: 'company1',
        userId: 'manager1',
        role: FleetRole.manager,
      );
      await seedMember(
        companyId: 'company1',
        userId: 'staff1',
        role: FleetRole.staff,
      );

      final result = await service.getMembers('company1');

      expect(result.isSuccess, true);
      expect(result.valueOrNull!.length, 3);
    });

    test('returns empty list for company with no members', () async {
      final result = await service.getMembers('emptyCompany');

      expect(result.isSuccess, true);
      expect(result.valueOrNull!, isEmpty);
    });

    test('does not return members of other companies', () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');
      await seedOwner(companyId: 'company2', userId: 'owner2');

      final result = await service.getMembers('company1');

      expect(result.isSuccess, true);
      expect(result.valueOrNull!.length, 1);
      expect(result.valueOrNull!.first.companyId, 'company1');
    });

    group('Edge Cases', () {
      test('empty companyId returns validation error', () async {
        final result = await service.getMembers('');

        expect(result.isFailure, true);
        expect(result.errorOrNull, isA<ValidationError>());
      });
    });
  });

  // ──────────────────────────────────────────────
  // getMemberRole
  // ──────────────────────────────────────────────
  group('getMemberRole', () {
    test('returns owner role for owner', () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');

      final result = await service.getMemberRole(
        companyId: 'company1',
        userId: 'owner1',
      );

      expect(result.isSuccess, true);
      expect(result.valueOrNull, FleetRole.owner);
    });

    test('returns null for non-member', () async {
      final result = await service.getMemberRole(
        companyId: 'company1',
        userId: 'outsider',
      );

      expect(result.isSuccess, true);
      expect(result.valueOrNull, isNull);
    });

    test('returns correct role for staff', () async {
      await seedMember(
        companyId: 'company1',
        userId: 'staff1',
        role: FleetRole.staff,
      );

      final result = await service.getMemberRole(
        companyId: 'company1',
        userId: 'staff1',
      );

      expect(result.isSuccess, true);
      expect(result.valueOrNull, FleetRole.staff);
    });

    group('Edge Cases', () {
      test('empty companyId returns validation error', () async {
        final result = await service.getMemberRole(
          companyId: '',
          userId: 'user1',
        );

        expect(result.isFailure, true);
        expect(result.errorOrNull, isA<ValidationError>());
      });

      test('empty userId returns validation error', () async {
        final result = await service.getMemberRole(
          companyId: 'company1',
          userId: '',
        );

        expect(result.isFailure, true);
        expect(result.errorOrNull, isA<ValidationError>());
      });
    });
  });

  // ──────────────────────────────────────────────
  // canWrite
  // ──────────────────────────────────────────────
  group('canWrite', () {
    test('owner can write', () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');

      final result = await service.canWrite(
        companyId: 'company1',
        userId: 'owner1',
      );

      expect(result.isSuccess, true);
      expect(result.valueOrNull, true);
    });

    test('manager can write', () async {
      await seedMember(
        companyId: 'company1',
        userId: 'manager1',
        role: FleetRole.manager,
      );

      final result = await service.canWrite(
        companyId: 'company1',
        userId: 'manager1',
      );

      expect(result.isSuccess, true);
      expect(result.valueOrNull, true);
    });

    test('staff cannot write', () async {
      await seedMember(
        companyId: 'company1',
        userId: 'staff1',
        role: FleetRole.staff,
      );

      final result = await service.canWrite(
        companyId: 'company1',
        userId: 'staff1',
      );

      expect(result.isSuccess, true);
      expect(result.valueOrNull, false);
    });

    test('viewer cannot write', () async {
      await seedMember(
        companyId: 'company1',
        userId: 'viewer1',
        role: FleetRole.viewer,
      );

      final result = await service.canWrite(
        companyId: 'company1',
        userId: 'viewer1',
      );

      expect(result.isSuccess, true);
      expect(result.valueOrNull, false);
    });

    test('non-member cannot write', () async {
      final result = await service.canWrite(
        companyId: 'company1',
        userId: 'outsider',
      );

      expect(result.isSuccess, true);
      expect(result.valueOrNull, false);
    });

    group('Edge Cases', () {
      test('empty companyId returns validation error', () async {
        final result = await service.canWrite(
          companyId: '',
          userId: 'user1',
        );

        expect(result.isFailure, true);
        expect(result.errorOrNull, isA<ValidationError>());
      });
    });
  });

  // ──────────────────────────────────────────────
  // FleetMember model
  // ──────────────────────────────────────────────
  group('FleetMember model', () {
    test('fromFirestore and toMap roundtrip', () async {
      await seedMember(
        companyId: 'company1',
        userId: 'staff1',
        role: FleetRole.staff,
        displayName: 'John Doe',
      );

      final result = await service.getMembers('company1');
      expect(result.isSuccess, true);

      final member = result.valueOrNull!.first;
      expect(member.displayName, 'John Doe');
      expect(member.role, FleetRole.staff);

      final map = member.toMap();
      expect(map['role'], 'staff');
      expect(map['displayName'], 'John Doe');
    });

    test('copyWith preserves unchanged fields', () async {
      await seedOwner(companyId: 'company1', userId: 'owner1');
      final result = await service.getMembers('company1');
      final member = result.valueOrNull!.first;

      final updated = member.copyWith(role: FleetRole.manager);
      expect(updated.role, FleetRole.manager);
      expect(updated.userId, member.userId);
      expect(updated.companyId, member.companyId);
    });
  });
}
