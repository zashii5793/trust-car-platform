// Unit tests for server-side comment moderation (report aggregation).
// The trigger wrapper lives in index.ts; the pure logic + DI handler live in
// src/moderateComments.ts so they can be tested without emulators.

import {
  REPORT_HIDE_THRESHOLD,
  computeModeration,
  resolveReportTarget,
  handleReportCreated,
  type CommentReportData,
  type ModerationTarget,
  type ModerationUpdate,
} from "../src/moderateComments";

describe("resolveReportTarget", () => {
  it("valid report → returns target", () => {
    const data: CommentReportData = {
      showcaseId: "sc-1",
      commentId: "c-1",
      reporterId: "u-1",
    };
    expect(resolveReportTarget(data)).toEqual({
      showcaseId: "sc-1",
      commentId: "c-1",
    });
  });

  it("missing showcaseId → null", () => {
    expect(resolveReportTarget({ commentId: "c-1" })).toBeNull();
  });

  it("missing commentId → null", () => {
    expect(resolveReportTarget({ showcaseId: "sc-1" })).toBeNull();
  });

  it("empty object → null", () => {
    expect(resolveReportTarget({})).toBeNull();
  });
});

describe("computeModeration", () => {
  it("below threshold → not hidden", () => {
    expect(computeModeration(2)).toEqual({ reportCount: 2, isHidden: false });
  });

  it("at threshold → hidden", () => {
    expect(computeModeration(REPORT_HIDE_THRESHOLD)).toEqual({
      reportCount: REPORT_HIDE_THRESHOLD,
      isHidden: true,
    });
  });

  it("above threshold → hidden", () => {
    expect(computeModeration(10)).toEqual({ reportCount: 10, isHidden: true });
  });

  describe("Edge Cases", () => {
    it("zero → not hidden, count 0", () => {
      expect(computeModeration(0)).toEqual({ reportCount: 0, isHidden: false });
    });

    it("negative → clamped to 0", () => {
      expect(computeModeration(-5)).toEqual({ reportCount: 0, isHidden: false });
    });

    it("non-integer → floored", () => {
      expect(computeModeration(3.9)).toEqual({ reportCount: 3, isHidden: true });
    });

    it("NaN → clamped to 0", () => {
      expect(computeModeration(Number.NaN)).toEqual({
        reportCount: 0,
        isHidden: false,
      });
    });

    it("custom threshold is honoured", () => {
      expect(computeModeration(2, 2)).toEqual({ reportCount: 2, isHidden: true });
      expect(computeModeration(1, 2)).toEqual({
        reportCount: 1,
        isHidden: false,
      });
    });
  });
});

describe("handleReportCreated", () => {
  function makeDeps(count: number) {
    const updateComment = jest
      .fn<Promise<void>, [ModerationTarget, ModerationUpdate]>()
      .mockResolvedValue(undefined);
    const countReports = jest
      .fn<Promise<number>, [ModerationTarget]>()
      .mockResolvedValue(count);
    return { countReports, updateComment };
  }

  it("aggregates the authoritative count and writes it to the comment", async () => {
    const deps = makeDeps(1);
    const res = await handleReportCreated(
      { showcaseId: "sc-1", commentId: "c-1", reporterId: "u-1" },
      deps
    );

    expect(deps.countReports).toHaveBeenCalledWith({
      showcaseId: "sc-1",
      commentId: "c-1",
    });
    expect(deps.updateComment).toHaveBeenCalledWith(
      { showcaseId: "sc-1", commentId: "c-1" },
      { reportCount: 1, isHidden: false }
    );
    expect(res).toEqual({ applied: true, update: { reportCount: 1, isHidden: false } });
  });

  it("hides the comment once the server count reaches the threshold", async () => {
    const deps = makeDeps(REPORT_HIDE_THRESHOLD);
    const res = await handleReportCreated(
      { showcaseId: "sc-1", commentId: "c-1" },
      deps
    );

    expect(deps.updateComment).toHaveBeenCalledWith(
      { showcaseId: "sc-1", commentId: "c-1" },
      { reportCount: REPORT_HIDE_THRESHOLD, isHidden: true }
    );
    expect(res.applied).toBe(true);
    expect(res.update?.isHidden).toBe(true);
  });

  it("does not trust a client-supplied count — always re-counts server-side", async () => {
    // Even if a malicious client stuffed reportCount into the report doc,
    // the handler ignores it and uses countReports().
    const deps = makeDeps(1);
    await handleReportCreated(
      { showcaseId: "sc-1", commentId: "c-1", reportCount: 999 } as CommentReportData,
      deps
    );
    expect(deps.updateComment).toHaveBeenCalledWith(
      { showcaseId: "sc-1", commentId: "c-1" },
      { reportCount: 1, isHidden: false }
    );
  });

  describe("Edge Cases", () => {
    it("malformed report (no target) → no write, applied false", async () => {
      const deps = makeDeps(5);
      const res = await handleReportCreated({}, deps);
      expect(deps.countReports).not.toHaveBeenCalled();
      expect(deps.updateComment).not.toHaveBeenCalled();
      expect(res).toEqual({ applied: false });
    });
  });
});
