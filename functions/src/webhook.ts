// RevenueCat → Firestore subscription webhook handler.
//
// RevenueCat sends a POST request to this function after every subscription
// event. This function updates the shop's subscriptionStatus and planType
// in Firestore — the only path with write access to those fields (firestore.rules).
//
// Security: Authorization header is validated against REVENUECAT_WEBHOOK_SECRET.
// Set the secret with: firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET

import type {
  PlanType,
  RevenueCatEventType,
  RevenueCatPeriodType,
  RevenueCatWebhookBody,
  ShopSubscriptionUpdate,
  SubscriptionStatus,
} from "./types";

// Product ID → PlanType mapping (must match RevenueCat dashboard & Flutter app).
const PRODUCT_TO_PLAN: Record<string, PlanType> = {
  trustcar_btob_standard_monthly: "standard",
  trustcar_btob_premium_monthly: "premium",
  trustcar_btob_enterprise_monthly: "enterprise",
};

/**
 * Maps a RevenueCat event type + period type to a Firestore subscriptionStatus.
 * Returns null for events that don't require a status update (e.g. TEST).
 */
export function resolveStatus(
  eventType: RevenueCatEventType,
  periodType: RevenueCatPeriodType
): SubscriptionStatus | null {
  switch (eventType) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "UNCANCELLATION":
      return periodType === "TRIAL" ? "trialing" : "active";
    case "CANCELLATION":
      // Still has access until expiration — mark cancelled but keep plan active.
      return "cancelled";
    case "EXPIRATION":
      return "expired";
    case "BILLING_ISSUE":
      return "pastDue";
    case "PRODUCT_CHANGE":
      // Product change itself doesn't change status; plan update happens separately.
      return "active";
    case "TEST":
    case "SUBSCRIBER_ALIAS":
    case "NON_RENEWING_PURCHASE":
      return null;
    default:
      return null;
  }
}

/**
 * Resolves the effective PlanType from a RevenueCat product ID.
 * Falls back to 'free' for unknown product IDs.
 */
export function resolvePlan(productId: string): PlanType {
  return PRODUCT_TO_PLAN[productId] ?? "free";
}

/**
 * Builds the Firestore update payload from a RevenueCat webhook body.
 * Returns null if the event does not require a Firestore update.
 */
export function buildUpdate(
  body: RevenueCatWebhookBody
): ShopSubscriptionUpdate | null {
  const { event } = body;
  const status = resolveStatus(event.type, event.period_type);
  if (status === null) return null;

  const plan = resolvePlan(event.product_id);

  const expiresAt =
    event.expiration_at_ms != null
      ? new Date(event.expiration_at_ms)
      : null;

  return {
    subscriptionStatus: status,
    planType:
      status === "expired"
        ? "free" // downgrade to free on expiration
        : plan,
    revenueCatUserId: event.app_user_id,
    subscriptionExpiresAt: expiresAt,
    updatedAt: new Date(),
  };
}

/**
 * Validates that the Authorization header matches the expected webhook secret.
 * RevenueCat sends the secret as a plain-text bearer token.
 */
export function isAuthorized(
  authHeader: string | undefined,
  expectedSecret: string
): boolean {
  if (!authHeader) return false;
  const [scheme, token] = authHeader.split(" ");
  if (scheme !== "Bearer" && scheme !== undefined) {
    // RevenueCat may send the secret without the Bearer prefix.
    return authHeader === expectedSecret;
  }
  return token === expectedSecret || authHeader === expectedSecret;
}

/**
 * Core handler logic — separated from the Firebase Function wrapper
 * so it can be unit-tested without emulators.
 */
export async function handleWebhook(
  authHeader: string | undefined,
  rawBody: unknown,
  webhookSecret: string,
  updateFirestore: (shopId: string, data: ShopSubscriptionUpdate) => Promise<void>
): Promise<{ status: number; message: string }> {
  // 1. Authenticate the request.
  if (!isAuthorized(authHeader, webhookSecret)) {
    return { status: 401, message: "Unauthorized" };
  }

  // 2. Validate the request body.
  if (
    typeof rawBody !== "object" ||
    rawBody === null ||
    !("event" in rawBody)
  ) {
    return { status: 400, message: "Invalid request body" };
  }

  const body = rawBody as RevenueCatWebhookBody;

  if (!body.event?.app_user_id) {
    return { status: 400, message: "Missing app_user_id in event" };
  }

  // 3. Build Firestore update.
  const update = buildUpdate(body);
  if (update === null) {
    // Event type does not require a Firestore update (e.g. TEST).
    return { status: 200, message: `Event ${body.event.type} acknowledged, no update needed` };
  }

  // 4. app_user_id is the Firebase Auth UID (= shopId, since shop doc ID == owner UID).
  const shopId = body.event.app_user_id;

  try {
    await updateFirestore(shopId, update);
    return {
      status: 200,
      message: `Shop ${shopId} updated: ${update.subscriptionStatus} / ${update.planType}`,
    };
  } catch (err) {
    console.error("Firestore update failed:", err);
    return { status: 500, message: "Internal server error" };
  }
}
