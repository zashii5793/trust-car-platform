/// Models for the in-app "What's New" (release notes) screen.
///
/// Release notes ship with the app binary (see [kBundledReleaseNotes] in
/// `release_notes_service.dart`) so the screen is never empty and requires no
/// backend, matching the natural 1:1 relationship between an app version and
/// its changelog.

/// Type of a single release-note highlight, used for the colored badge.
enum ReleaseHighlightType {
  /// New capability added in this version.
  feature('新機能'),

  /// Existing behaviour improved.
  improvement('改善'),

  /// Bug fixed.
  fix('修正');

  const ReleaseHighlightType(this.label);

  /// Japanese label shown in the UI badge.
  final String label;
}

/// A single bullet within a version's release note.
class ReleaseHighlight {
  final ReleaseHighlightType type;
  final String title;
  final String description;

  const ReleaseHighlight({
    required this.type,
    required this.title,
    this.description = '',
  });
}

/// Release note for one app version.
class AppReleaseNote {
  /// Semantic version string, e.g. `"1.0.0"`.
  final String version;

  /// Release date.
  final DateTime releasedAt;

  /// Prominent one-line summary (the product's selling point for the first
  /// release: vehicle history carries over across any shop).
  final String headline;

  /// Detailed highlights, rendered as a list.
  final List<ReleaseHighlight> highlights;

  const AppReleaseNote({
    required this.version,
    required this.releasedAt,
    required this.headline,
    required this.highlights,
  });
}
