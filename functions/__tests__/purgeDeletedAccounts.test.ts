// Unit tests for the deleted-account purge.
// The scheduled-trigger wrapper lives in index.ts; the pure logic + DI handler
// live in src/purgeDeletedAccounts.ts so they can be tested without emulators.

import {
  PURGE_AFTER_DAYS,
  USER_OWNED_COLLECTIONS,
  handleScheduledPurge,
  isDue,
  storagePrefixesFor,
  type DeletionMarker,
  type PurgeDeps,
} from "../src/purgeDeletedAccounts";

const DAY = 24 * 60 * 60 * 1000;
const NOW = 1_700_000_000_000;

function marker(status: string, daysAgo: number | null): DeletionMarker {
  return {
    uid: "u1",
    status,
    requestedAt:
      daysAgo === null ? undefined : { toMillis: () => NOW - daysAgo * DAY },
  };
}

describe("isDue", () => {
  it("pending & just requested → due (no grace period)", () => {
    expect(isDue(marker("pending", 0), NOW)).toBe(true);
  });

  it("pending & a day old → due", () => {
    expect(isDue(marker("pending", 1), NOW)).toBe(true);
  });

  it("pending & 30 days old → still due", () => {
    expect(isDue(marker("pending", 30), NOW)).toBe(true);
  });

  it("completed marker → never due again", () => {
    expect(isDue(marker("completed", 60), NOW)).toBe(false);
  });

  it("missing requestedAt → due (the promise must not be skippable)", () => {
    expect(isDue(marker("pending", null), NOW)).toBe(true);
  });

  it("missing status → not due", () => {
    expect(isDue({ uid: "u1" }, NOW)).toBe(false);
  });
});

describe("handleScheduledPurge", () => {
  function makeDeps(overrides: Partial<PurgeDeps> = {}): {
    deps: PurgeDeps;
    calls: string[];
  } {
    const calls: string[] = [];
    const deps: PurgeDeps = {
      listDueMarkers: async () => ["u1"],
      deleteByUserId: async (collection, uid) => {
        calls.push(`delete:${collection}:${uid}`);
        return collection === "drive_logs" ? ["dl-1", "dl-2"] : [];
      },
      deleteWaypointsFor: async (ids) => {
        calls.push(`waypoints:${ids.join(",")}`);
      },
      deleteUserDoc: async (uid) => {
        calls.push(`userDoc:${uid}`);
      },
      deleteStoragePrefix: async (prefix) => {
        calls.push(`storage:${prefix}`);
      },
      markCompleted: async (uid) => {
        calls.push(`completed:${uid}`);
      },
      ...overrides,
    };
    return { deps, calls };
  }

  it("deletes every user-owned collection, waypoints, storage, user doc", async () => {
    const { deps, calls } = makeDeps();

    const result = await handleScheduledPurge(deps);

    expect(result.purgedUids).toEqual(["u1"]);
    expect(result.failedUids).toEqual([]);
    for (const collection of USER_OWNED_COLLECTIONS) {
      expect(calls).toContain(`delete:${collection}:u1`);
    }
    expect(calls).toContain("waypoints:dl-1,dl-2");
    expect(calls).toContain("userDoc:u1");
    for (const prefix of storagePrefixesFor("u1")) {
      expect(calls).toContain(`storage:${prefix}`);
    }
  });

  it("marks the marker completed LAST", async () => {
    const { deps, calls } = makeDeps();

    await handleScheduledPurge(deps);

    expect(calls[calls.length - 1]).toBe("completed:u1");
  });

  it("one failing account does not block the others", async () => {
    const { deps } = makeDeps({
      listDueMarkers: async () => ["bad", "good"],
      deleteByUserId: async (collection, uid) => {
        if (uid === "bad") throw new Error("corrupt doc");
        return [];
      },
    });

    const result = await handleScheduledPurge(deps);

    expect(result.failedUids).toEqual(["bad"]);
    expect(result.purgedUids).toEqual(["good"]);
  });

  it("a failed purge does NOT mark the marker completed (retry next run)", async () => {
    const completed: string[] = [];
    const { deps } = makeDeps({
      deleteStoragePrefix: async () => {
        throw new Error("storage down");
      },
      markCompleted: async (uid) => {
        completed.push(uid);
      },
    });

    const result = await handleScheduledPurge(deps);

    expect(result.failedUids).toEqual(["u1"]);
    expect(completed).toEqual([]);
  });

  it("no due markers → no-op", async () => {
    const { deps, calls } = makeDeps({ listDueMarkers: async () => [] });

    const result = await handleScheduledPurge(deps);

    expect(result.purgedUids).toEqual([]);
    expect(calls).toEqual([]);
  });

  it("skips waypoint deletion when the user had no drive logs", async () => {
    const { deps, calls } = makeDeps({
      deleteByUserId: async () => [],
    });

    await handleScheduledPurge(deps);

    expect(calls.some((c) => c.startsWith("waypoints:"))).toBe(false);
  });
});

describe("constants", () => {
  // The policy says the data is deleted on withdrawal. If this number moves,
  // the retention section of the privacy policy has to move with it - they
  // are two statements of one promise.
  it("purge window matches the privacy policy (no grace period)", () => {
    expect(PURGE_AFTER_DAYS).toBe(0);
  });
});
