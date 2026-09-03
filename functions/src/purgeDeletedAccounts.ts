// Server-side purge for deleted accounts.
//
// Problem: the client writes an `account_deletions/{uid}` marker when a user
// deletes their account, and the privacy policy promises the user's data is
// removed — but nothing ever executed that promise. The marker sat in
// Firestore forever and no document was ever deleted.
//
// This module implements the purge. The scheduled-trigger wrapper lives in
// index.ts; the logic here is pure / dependency-injected so it can be
// unit-tested without emulators (same pattern as moderateComments.ts).
//
// Design notes:
// - There is no grace period (2026-09-03). The policy says the data is
//   deleted on withdrawal, so a marker is due the moment it is written and
//   the next nightly run removes it. That gives up support-side recovery of
//   an accidental deletion: once the Auth account is gone, nothing can be
//   restored. Reinstating a window means changing PURGE_AFTER_DAYS *and*
//   the retention section of the privacy policy together — they are two
//   statements of one promise.
// - Content that other users' data points at (comments on someone else's
//   post, likes) is deleted rather than anonymised: the privacy policy
//   promises deletion, so deletion is what happens.
// - Every step is idempotent: a crash mid-purge leaves the marker 'pending'
//   and the next run repeats the remaining deletes harmlessly.

/// Days a deletion request waits before the purge executes.
///
/// **Must match the privacy policy's retention section.** 0 = no grace
/// period: the nightly job removes the data on its first run after the
/// request, so a user who withdraws is gone by the next morning.
export const PURGE_AFTER_DAYS = 0;

/// Collections owned by a user via a `userId` field.
/// `drive_waypoints` is keyed by driveLogId, not userId, and is handled
/// separately in the handler below.
export const USER_OWNED_COLLECTIONS: readonly string[] = [
  "vehicles",
  "maintenance_records",
  "drive_logs",
  "posts",
  "comments",
  "post_likes",
  "comment_likes",
  "drive_log_likes",
  "inquiries",
  "fleet_members",
  "social_notifications",
  "user_part_listings",
];

/// Storage prefixes that hold a user's uploaded files.
export function storagePrefixesFor(uid: string): string[] {
  return [`profile_images/${uid}/`, `drive_logs/${uid}/`];
}

/// Shape of an `account_deletions/{uid}` marker document.
export interface DeletionMarker {
  uid?: string;
  status?: string;
  requestedAt?: { toMillis(): number };
}

/// Whether a marker is due for purging at [nowMillis].
///
/// A marker with no requestedAt is treated as due: it can only have been
/// written by the client flow (rules restrict creation to the account owner),
/// and leaving it forever would mean the promised deletion never runs.
export function isDue(marker: DeletionMarker, nowMillis: number): boolean {
  if (marker.status !== "pending") return false;
  const requested = marker.requestedAt?.toMillis();
  if (requested === undefined) return true;
  return nowMillis - requested >= PURGE_AFTER_DAYS * 24 * 60 * 60 * 1000;
}

/// Dependencies injected by the trigger wrapper (or tests).
export interface PurgeDeps {
  /// Returns uids of markers due for purging.
  listDueMarkers(): Promise<string[]>;
  /// Deletes all docs in [collection] where field `userId` == uid.
  /// Returns the ids of the deleted documents.
  deleteByUserId(collection: string, uid: string): Promise<string[]>;
  /// Deletes waypoints belonging to the given drive logs.
  deleteWaypointsFor(driveLogIds: string[]): Promise<void>;
  /// Deletes the `users/{uid}` document.
  deleteUserDoc(uid: string): Promise<void>;
  /// Deletes all Storage objects under [prefix].
  deleteStoragePrefix(prefix: string): Promise<void>;
  /// Marks the `account_deletions/{uid}` marker as completed.
  markCompleted(uid: string): Promise<void>;
}

/// Result summary for logging.
export interface PurgeResult {
  purgedUids: string[];
  failedUids: string[];
}

/**
 * Purges every account whose deletion marker is due.
 *
 * One account failing must not block the others — a single corrupt document
 * would otherwise freeze the entire purge pipeline (and the promise to every
 * other user). Failures are collected and reported, and the marker stays
 * 'pending' so the next scheduled run retries.
 */
export async function handleScheduledPurge(
  deps: PurgeDeps
): Promise<PurgeResult> {
  const uids = await deps.listDueMarkers();
  const purged: string[] = [];
  const failed: string[] = [];

  for (const uid of uids) {
    try {
      let driveLogIds: string[] = [];
      for (const collection of USER_OWNED_COLLECTIONS) {
        const deletedIds = await deps.deleteByUserId(collection, uid);
        if (collection === "drive_logs") driveLogIds = deletedIds;
      }
      if (driveLogIds.length > 0) {
        await deps.deleteWaypointsFor(driveLogIds);
      }
      for (const prefix of storagePrefixesFor(uid)) {
        await deps.deleteStoragePrefix(prefix);
      }
      await deps.deleteUserDoc(uid);
      // The marker is completed LAST: if anything above failed we want the
      // next run to retry, not to believe the purge finished.
      await deps.markCompleted(uid);
      purged.push(uid);
    } catch (err) {
      console.error(`Account purge failed for ${uid}:`, err);
      failed.push(uid);
    }
  }

  return { purgedUids: purged, failedUids: failed };
}
