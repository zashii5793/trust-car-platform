// Server-side moderation for showcase comment reports.
//
// Problem: clients used to increment `reportCount` on the comment document
// themselves (firestore.rules allowed a +1). Three colluding accounts could
// therefore hide any comment, and a single client could spam the counter
// without ever creating the matching comment_reports doc.
//
// Fix: clients may now ONLY create a `comment_reports/{commentId}_{reporterId}`
// document (one per user/comment, enforced by rules + deterministic id). This
// module runs as the service account, RE-COUNTS the authoritative number of
// reports for the comment, and writes `reportCount` + `isHidden` back to the
// comment — a value clients can no longer forge.
//
// The Firebase trigger wrapper lives in index.ts; the logic here is pure /
// dependency-injected so it can be unit-tested without emulators (same pattern
// as webhook.ts).

/// Number of distinct reports at which a comment is auto-hidden.
/// Must match `kReportHideThreshold` in the Flutter client
/// (lib/services/popular_accessories_service.dart).
export const REPORT_HIDE_THRESHOLD = 3;

/// Shape of a `comment_reports/{reportId}` document.
export interface CommentReportData {
  showcaseId?: string;
  commentId?: string;
  reporterId?: string;
}

/// Identifies the comment a report points at.
export interface ModerationTarget {
  showcaseId: string;
  commentId: string;
}

/// The moderation fields written back to the comment document.
export interface ModerationUpdate {
  reportCount: number;
  isHidden: boolean;
}

/**
 * Extracts the moderation target from a report document.
 * Returns null when the report is missing the fields needed to locate the
 * comment (in which case nothing can be moderated).
 */
export function resolveReportTarget(
  data: CommentReportData
): ModerationTarget | null {
  if (!data?.showcaseId || !data?.commentId) return null;
  return { showcaseId: data.showcaseId, commentId: data.commentId };
}

/**
 * Derives the moderation payload from an authoritative report count.
 * Counts are sanitised (floored, clamped to >= 0) so a bad aggregate can never
 * write a negative or fractional reportCount.
 */
export function computeModeration(
  reportCount: number,
  threshold: number = REPORT_HIDE_THRESHOLD
): ModerationUpdate {
  const safe =
    Number.isFinite(reportCount) && reportCount > 0
      ? Math.floor(reportCount)
      : 0;
  return { reportCount: safe, isHidden: safe >= threshold };
}

/** Injected side effects, mocked in tests. */
export interface ModerationDeps {
  /** Authoritative number of distinct reports for the target comment. */
  countReports: (target: ModerationTarget) => Promise<number>;
  /** Persists the moderation payload onto the comment document. */
  updateComment: (
    target: ModerationTarget,
    update: ModerationUpdate
  ) => Promise<void>;
}

/**
 * Core handler — runs when a new comment_reports document is created.
 * Re-counts server-side (ignoring anything the client may have stuffed into the
 * report doc) and writes the resulting reportCount / isHidden to the comment.
 */
export async function handleReportCreated(
  data: CommentReportData,
  deps: ModerationDeps,
  threshold: number = REPORT_HIDE_THRESHOLD
): Promise<{ applied: boolean; update?: ModerationUpdate }> {
  const target = resolveReportTarget(data);
  if (!target) return { applied: false };

  const count = await deps.countReports(target);
  const update = computeModeration(count, threshold);
  await deps.updateComment(target, update);
  return { applied: true, update };
}
