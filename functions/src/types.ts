// RevenueCat webhook types.
// Reference: https://www.revenuecat.com/docs/webhooks

export type RevenueCatEventType =
  | "INITIAL_PURCHASE"
  | "RENEWAL"
  | "CANCELLATION"
  | "UNCANCELLATION"
  | "NON_RENEWING_PURCHASE"
  | "EXPIRATION"
  | "BILLING_ISSUE"
  | "PRODUCT_CHANGE"
  | "SUBSCRIBER_ALIAS"
  | "TEST";

export type RevenueCatEnvironment = "PRODUCTION" | "SANDBOX";
export type RevenueCatStore = "PLAY_STORE" | "APP_STORE";
export type RevenueCatPeriodType = "TRIAL" | "INTRO" | "NORMAL";

export interface RevenueCatWebhookEvent {
  type: RevenueCatEventType;
  id: string;
  /** Firebase Auth UID of the shop owner — set as RevenueCat appUserID. */
  app_user_id: string;
  original_app_user_id: string;
  aliases: string[];
  product_id: string;
  period_type: RevenueCatPeriodType;
  purchased_at_ms: number;
  expiration_at_ms: number | null;
  environment: RevenueCatEnvironment;
  is_family_share: boolean;
  currency: string;
  price: number;
  price_in_purchased_currency: number;
  subscriber_attributes: Record<
    string,
    { value: string; updated_at_ms: number }
  >;
  store: RevenueCatStore;
  offer_code: string | null;
}

export interface RevenueCatWebhookBody {
  api_version: string;
  event: RevenueCatWebhookEvent;
}

// Mirrors ShopSubscriptionStatus enum in the Flutter app.
export type SubscriptionStatus =
  | "active"
  | "trialing"
  | "cancelled"
  | "expired"
  | "pastDue";

// Mirrors ShopPlanType enum in the Flutter app.
export type PlanType = "free" | "standard" | "premium" | "enterprise";

export interface ShopSubscriptionUpdate {
  subscriptionStatus: SubscriptionStatus;
  planType: PlanType;
  revenueCatUserId: string;
  subscriptionExpiresAt: Date | null;
  updatedAt: Date;
}
