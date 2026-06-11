// Unit tests for RevenueCat webhook handler.
// Tests cover all subscription event types, authorization checks,
// and Firestore update payload generation — no emulators required.

import {
  buildUpdate,
  handleWebhook,
  isAuthorized,
  resolvePlan,
  resolveStatus,
} from "../src/webhook";
import type {
  RevenueCatWebhookBody,
  ShopSubscriptionUpdate,
} from "../src/types";

const SECRET = "test-webhook-secret-abc123";
const SHOP_ID = "uid-shop-owner-001";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeBody(
  eventType: string,
  productId = "trustcar_btob_standard_monthly",
  periodType = "NORMAL",
  expiresAt: number | null = 9999999999000
): RevenueCatWebhookBody {
  return {
    api_version: "1.0",
    event: {
      type: eventType as never,
      id: "evt-test-001",
      app_user_id: SHOP_ID,
      original_app_user_id: SHOP_ID,
      aliases: [],
      product_id: productId,
      period_type: periodType as never,
      purchased_at_ms: Date.now(),
      expiration_at_ms: expiresAt,
      environment: "SANDBOX",
      is_family_share: false,
      currency: "JPY",
      price: 3980,
      price_in_purchased_currency: 3980,
      subscriber_attributes: {},
      store: "PLAY_STORE",
      offer_code: null,
    },
  };
}

// ---------------------------------------------------------------------------
// resolveStatus
// ---------------------------------------------------------------------------

describe("resolveStatus", () => {
  it("INITIAL_PURCHASE + NORMAL → active", () => {
    expect(resolveStatus("INITIAL_PURCHASE", "NORMAL")).toBe("active");
  });

  it("INITIAL_PURCHASE + TRIAL → trialing", () => {
    expect(resolveStatus("INITIAL_PURCHASE", "TRIAL")).toBe("trialing");
  });

  it("RENEWAL → active", () => {
    expect(resolveStatus("RENEWAL", "NORMAL")).toBe("active");
  });

  it("CANCELLATION → cancelled (still has access until expiry)", () => {
    expect(resolveStatus("CANCELLATION", "NORMAL")).toBe("cancelled");
  });

  it("EXPIRATION → expired", () => {
    expect(resolveStatus("EXPIRATION", "NORMAL")).toBe("expired");
  });

  it("BILLING_ISSUE → pastDue", () => {
    expect(resolveStatus("BILLING_ISSUE", "NORMAL")).toBe("pastDue");
  });

  it("UNCANCELLATION → active", () => {
    expect(resolveStatus("UNCANCELLATION", "NORMAL")).toBe("active");
  });

  it("PRODUCT_CHANGE → active", () => {
    expect(resolveStatus("PRODUCT_CHANGE", "NORMAL")).toBe("active");
  });

  it("TEST → null (no update needed)", () => {
    expect(resolveStatus("TEST", "NORMAL")).toBeNull();
  });

  it("SUBSCRIBER_ALIAS → null", () => {
    expect(resolveStatus("SUBSCRIBER_ALIAS", "NORMAL")).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// resolvePlan
// ---------------------------------------------------------------------------

describe("resolvePlan", () => {
  it("standard product ID → standard", () => {
    expect(resolvePlan("trustcar_btob_standard_monthly")).toBe("standard");
  });

  it("premium product ID → premium", () => {
    expect(resolvePlan("trustcar_btob_premium_monthly")).toBe("premium");
  });

  it("enterprise product ID → enterprise", () => {
    expect(resolvePlan("trustcar_btob_enterprise_monthly")).toBe("enterprise");
  });

  it("unknown product ID → free (safe fallback)", () => {
    expect(resolvePlan("unknown_product_xyz")).toBe("free");
  });
});

// ---------------------------------------------------------------------------
// buildUpdate
// ---------------------------------------------------------------------------

describe("buildUpdate", () => {
  it("INITIAL_PURCHASE → active update payload", () => {
    const body = makeBody("INITIAL_PURCHASE");
    const update = buildUpdate(body);
    expect(update).not.toBeNull();
    expect(update!.subscriptionStatus).toBe("active");
    expect(update!.planType).toBe("standard");
    expect(update!.revenueCatUserId).toBe(SHOP_ID);
    expect(update!.subscriptionExpiresAt).toBeInstanceOf(Date);
  });

  it("EXPIRATION → expired + planType downgraded to free", () => {
    const body = makeBody("EXPIRATION");
    const update = buildUpdate(body);
    expect(update!.subscriptionStatus).toBe("expired");
    expect(update!.planType).toBe("free");
  });

  it("CANCELLATION → cancelled + plan retained (access until expiry)", () => {
    const body = makeBody("CANCELLATION", "trustcar_btob_premium_monthly");
    const update = buildUpdate(body);
    expect(update!.subscriptionStatus).toBe("cancelled");
    expect(update!.planType).toBe("premium");
  });

  it("BILLING_ISSUE → pastDue", () => {
    const body = makeBody("BILLING_ISSUE");
    const update = buildUpdate(body);
    expect(update!.subscriptionStatus).toBe("pastDue");
  });

  it("TEST event → returns null (no Firestore update)", () => {
    const body = makeBody("TEST");
    expect(buildUpdate(body)).toBeNull();
  });

  it("null expiration_at_ms → subscriptionExpiresAt is null", () => {
    const body = makeBody("INITIAL_PURCHASE", "trustcar_btob_standard_monthly", "NORMAL", null);
    const update = buildUpdate(body);
    expect(update!.subscriptionExpiresAt).toBeNull();
  });

  it("enterprise plan upgrade → planType enterprise", () => {
    const body = makeBody("PRODUCT_CHANGE", "trustcar_btob_enterprise_monthly");
    const update = buildUpdate(body);
    expect(update!.planType).toBe("enterprise");
    expect(update!.subscriptionStatus).toBe("active");
  });
});

// ---------------------------------------------------------------------------
// isAuthorized
// ---------------------------------------------------------------------------

describe("isAuthorized", () => {
  it("matching Bearer token → authorized", () => {
    expect(isAuthorized(`Bearer ${SECRET}`, SECRET)).toBe(true);
  });

  it("matching plain token (no Bearer prefix) → authorized", () => {
    expect(isAuthorized(SECRET, SECRET)).toBe(true);
  });

  it("wrong token → not authorized", () => {
    expect(isAuthorized("Bearer wrong-secret", SECRET)).toBe(false);
  });

  it("undefined header → not authorized", () => {
    expect(isAuthorized(undefined, SECRET)).toBe(false);
  });

  it("empty string → not authorized", () => {
    expect(isAuthorized("", SECRET)).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// handleWebhook (integration-style, no emulators)
// ---------------------------------------------------------------------------

describe("handleWebhook", () => {
  const mockUpdateFirestore = jest.fn().mockResolvedValue(undefined);

  beforeEach(() => {
    mockUpdateFirestore.mockClear();
  });

  it("valid INITIAL_PURCHASE → 200 and calls updateFirestore", async () => {
    const body = makeBody("INITIAL_PURCHASE");
    const result = await handleWebhook(
      `Bearer ${SECRET}`,
      body,
      SECRET,
      mockUpdateFirestore
    );
    expect(result.status).toBe(200);
    expect(mockUpdateFirestore).toHaveBeenCalledTimes(1);
    const [calledShopId, calledData] = mockUpdateFirestore.mock.calls[0] as [
      string,
      ShopSubscriptionUpdate
    ];
    expect(calledShopId).toBe(SHOP_ID);
    expect(calledData.subscriptionStatus).toBe("active");
    expect(calledData.planType).toBe("standard");
  });

  it("EXPIRATION → Firestore updated with expired + free plan", async () => {
    const body = makeBody("EXPIRATION");
    const result = await handleWebhook(
      `Bearer ${SECRET}`,
      body,
      SECRET,
      mockUpdateFirestore
    );
    expect(result.status).toBe(200);
    const [, data] = mockUpdateFirestore.mock.calls[0] as [string, ShopSubscriptionUpdate];
    expect(data.subscriptionStatus).toBe("expired");
    expect(data.planType).toBe("free");
  });

  it("TEST event → 200 but Firestore NOT updated", async () => {
    const body = makeBody("TEST");
    const result = await handleWebhook(
      `Bearer ${SECRET}`,
      body,
      SECRET,
      mockUpdateFirestore
    );
    expect(result.status).toBe(200);
    expect(mockUpdateFirestore).not.toHaveBeenCalled();
  });

  it("wrong Authorization → 401", async () => {
    const body = makeBody("INITIAL_PURCHASE");
    const result = await handleWebhook(
      "Bearer wrong-secret",
      body,
      SECRET,
      mockUpdateFirestore
    );
    expect(result.status).toBe(401);
    expect(mockUpdateFirestore).not.toHaveBeenCalled();
  });

  it("missing Authorization → 401", async () => {
    const body = makeBody("INITIAL_PURCHASE");
    const result = await handleWebhook(undefined, body, SECRET, mockUpdateFirestore);
    expect(result.status).toBe(401);
  });

  it("invalid body (not an object) → 400", async () => {
    const result = await handleWebhook(
      `Bearer ${SECRET}`,
      "not-an-object",
      SECRET,
      mockUpdateFirestore
    );
    expect(result.status).toBe(400);
  });

  it("body missing event → 400", async () => {
    const result = await handleWebhook(
      `Bearer ${SECRET}`,
      { api_version: "1.0" },
      SECRET,
      mockUpdateFirestore
    );
    expect(result.status).toBe(400);
  });

  it("body missing app_user_id → 400", async () => {
    const body = makeBody("INITIAL_PURCHASE");
    (body.event as unknown as Record<string, unknown>).app_user_id = "";
    const result = await handleWebhook(
      `Bearer ${SECRET}`,
      body,
      SECRET,
      mockUpdateFirestore
    );
    expect(result.status).toBe(400);
  });

  it("Firestore failure → 500", async () => {
    const failingUpdate = jest.fn().mockRejectedValue(new Error("Firestore down"));
    const body = makeBody("RENEWAL");
    const result = await handleWebhook(
      `Bearer ${SECRET}`,
      body,
      SECRET,
      failingUpdate
    );
    expect(result.status).toBe(500);
  });

  it("CANCELLATION → 200, status=cancelled but plan retained", async () => {
    const body = makeBody("CANCELLATION", "trustcar_btob_premium_monthly");
    const result = await handleWebhook(
      `Bearer ${SECRET}`,
      body,
      SECRET,
      mockUpdateFirestore
    );
    expect(result.status).toBe(200);
    const [, data] = mockUpdateFirestore.mock.calls[0] as [string, ShopSubscriptionUpdate];
    expect(data.subscriptionStatus).toBe("cancelled");
    expect(data.planType).toBe("premium");
  });

  it("BILLING_ISSUE → pastDue", async () => {
    const body = makeBody("BILLING_ISSUE");
    await handleWebhook(`Bearer ${SECRET}`, body, SECRET, mockUpdateFirestore);
    const [, data] = mockUpdateFirestore.mock.calls[0] as [string, ShopSubscriptionUpdate];
    expect(data.subscriptionStatus).toBe("pastDue");
  });
});
