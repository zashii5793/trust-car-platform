import 'package:cloud_firestore/cloud_firestore.dart';

/// Roles available to fleet members
///
/// owner   — full permissions (add/remove members, link vehicles, assign, CSV export)
/// manager — link vehicles, assign staff, CSV export (cannot add/remove members)
/// staff   — view own assigned vehicles, update inspection date only
/// viewer  — read-only access
enum FleetRole {
  owner,
  manager,
  staff,
  viewer;

  static FleetRole fromString(String? value) {
    if (value == null) return FleetRole.viewer;
    try {
      return FleetRole.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return FleetRole.viewer;
    }
  }
}

/// A member belonging to a company fleet
class FleetMember {
  final String id; // Firestore document ID: {companyId}_{userId}
  final String companyId;
  final String userId;
  final FleetRole role;
  final String? displayName;
  final DateTime joinedAt;

  const FleetMember({
    required this.id,
    required this.companyId,
    required this.userId,
    required this.role,
    this.displayName,
    required this.joinedAt,
  });

  factory FleetMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FleetMember(
      id: doc.id,
      companyId: data['companyId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      role: FleetRole.fromString(data['role'] as String?),
      displayName: data['displayName'] as String?,
      joinedAt: _parseDateTime(data['joinedAt']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'userId': userId,
      'role': role.name,
      'displayName': displayName,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  FleetMember copyWith({
    String? id,
    String? companyId,
    String? userId,
    FleetRole? role,
    String? displayName,
    DateTime? joinedAt,
  }) {
    return FleetMember(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FleetMember && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FleetMember($id, role: ${role.name})';
}
