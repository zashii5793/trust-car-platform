import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/app_release_note.dart';

/// Supplies the list of release notes.
///
/// Injectable so tests can provide fixtures and a remote source can replace the
/// bundled data in the future without changing [ReleaseNotesService]'s contract.
typedef ReleaseNotesSource = List<AppReleaseNote> Function();

/// Provides the in-app "What's New" content.
///
/// By default the data is bundled with the app binary ([kBundledReleaseNotes]),
/// so the screen works offline, is never empty on a fresh install, and needs no
/// Firestore rules or seeding. Each method returns a [Result] for consistency
/// with the rest of the service layer.
class ReleaseNotesService {
  final ReleaseNotesSource _source;

  ReleaseNotesService({ReleaseNotesSource? source})
      : _source = source ?? (() => kBundledReleaseNotes);

  /// Returns every release note, newest version first.
  Result<List<AppReleaseNote>, AppError> getReleaseNotes() {
    try {
      final notes = [..._source()]
        ..sort((a, b) => _compareVersionDesc(a.version, b.version));
      return Result.success(notes);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns the most recent release note, or a [NotFoundError] when none exist.
  Result<AppReleaseNote, AppError> latest() {
    return getReleaseNotes().flatMap((notes) {
      if (notes.isEmpty) {
        return const Result.failure(
          AppError.notFound('No release notes available'),
        );
      }
      return Result.success(notes.first);
    });
  }

  /// Compares two semantic version strings descending (newest first).
  ///
  /// Missing or non-numeric segments are treated as `0`, so malformed version
  /// strings sort deterministically instead of throwing.
  static int _compareVersionDesc(String a, String b) {
    final pa = _parseVersion(a);
    final pb = _parseVersion(b);
    for (var i = 0; i < 3; i++) {
      final cmp = pb[i].compareTo(pa[i]);
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  static List<int> _parseVersion(String v) {
    // Drop any build metadata after '+' (e.g. "1.0.0+3").
    final core = v.split('+').first;
    final parts = core.split('.');
    return List<int>.generate(
      3,
      (i) => i < parts.length ? (int.tryParse(parts[i].trim()) ?? 0) : 0,
    );
  }
}

/// Release notes shipped with the app binary.
///
/// Add a new [AppReleaseNote] at the top of this list with each release; the
/// What's New screen sorts and renders them automatically.
///
/// Note: this is a `final` (not `const`) list because [DateTime] has no const
/// constructor. [ReleaseNotesService.getReleaseNotes] copies it before sorting,
/// so the shared instance is never mutated.
final List<AppReleaseNote> kBundledReleaseNotes = [
  AppReleaseNote(
    version: '1.0.0',
    releasedAt: DateTime(2026, 6, 20),
    headline: '車両管理情報を“どの店舗でも”引き継げます',
    highlights: const [
      ReleaseHighlight(
        type: ReleaseHighlightType.feature,
        title: 'お店が変わっても、整備履歴はそのまま',
        description: 'ディーラーでも町の整備工場でも——どこで点検・整備を受けても、'
            '1台ぶんの記録が途切れず引き継がれます。乗り換えや引っ越しのときも、'
            'これまでの履歴をそのまま次のお店に共有できます。',
      ),
      ReleaseHighlight(
        type: ReleaseHighlightType.feature,
        title: '複数台をまとめて管理',
        description: 'ご家族の車も社用車も、1つのアプリで管理できます。'
            '法人向けのフリート管理にも対応しています。',
      ),
      ReleaseHighlight(
        type: ReleaseHighlightType.feature,
        title: '車検・整備のAIリマインド',
        description: '車検証の読み取りと整備履歴から、次の整備時期をAIがお知らせします。',
      ),
      ReleaseHighlight(
        type: ReleaseHighlightType.feature,
        title: 'みんなの整備記録',
        description: '同じ車種に乗る人の整備傾向を参考に、メンテナンスの計画が立てられます。',
      ),
    ],
  ),
];
