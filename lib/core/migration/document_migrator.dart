/// Lazy schema migration utility for Firestore documents.
///
/// See `docs/SCHEMA_MIGRATION_STRATEGY.md` for the design rationale.
///
/// A [DocumentMigrator] upgrades a raw Firestore document map from whatever
/// `schemaVersion` it was written with up to [currentVersion], applying each
/// registered [MigrationStep] in order. Models call this in `fromFirestore`
/// so that old documents are read as if they were written by the current app
/// version (lazy migration on read). The write path always stamps
/// [currentVersion], so a document only needs migrating until it is next saved.
///
/// Steps must be **pure and idempotent**: `migrate(migrate(x)) == migrate(x)`.
library;

/// Transforms a document map from version N to version N+1.
typedef MigrationStep = Map<String, dynamic> Function(
    Map<String, dynamic> data);

class DocumentMigrator {
  /// Field that stores the schema version on every persisted document.
  static const String versionField = 'schemaVersion';

  /// Map of `fromVersion -> step that produces fromVersion+1`.
  final Map<int, MigrationStep> _steps;

  /// The schema version the current app code expects.
  final int currentVersion;

  const DocumentMigrator(this._steps, {required this.currentVersion})
      : assert(currentVersion >= 1, 'currentVersion must be >= 1');

  /// Returns [data] upgraded to [currentVersion].
  ///
  /// - A missing or invalid `schemaVersion` is treated as version 1.
  /// - Documents already at or beyond [currentVersion] are returned unchanged
  ///   (forward compatibility: never downgrade data written by a newer app).
  /// - The input map is never mutated; a new map is returned when migrating.
  /// - Throws [StateError] if the chain is broken (a required step is missing),
  ///   to fail loudly rather than silently produce half-migrated data.
  Map<String, dynamic> migrate(Map<String, dynamic> data) {
    var version = _readVersion(data);

    // Already current (or newer): leave the document exactly as-is.
    if (version >= currentVersion) {
      return data;
    }

    var out = Map<String, dynamic>.from(data);
    while (version < currentVersion) {
      final step = _steps[version];
      if (step == null) {
        throw StateError(
          'No migration step registered from schemaVersion $version '
          'to ${version + 1} (target: $currentVersion).',
        );
      }
      out = step(out);
      version++;
    }
    out[versionField] = currentVersion;
    return out;
  }

  int _readVersion(Map<String, dynamic> data) {
    final raw = data[versionField];
    if (raw is int && raw >= 1) return raw;
    return 1; // missing / malformed → treat as the original v1
  }
}
