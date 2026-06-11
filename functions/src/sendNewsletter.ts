/**
 * Newsletter delivery Cloud Function.
 *
 * Trigger: Firestore document write on newsletters/{newsletterId}
 *          when status changes to "scheduled".
 *
 * What it does:
 *   1. Fetches the newsletter document.
 *   2. Queries newsletter_subscriptions for opted-in users matching the audience.
 *   3. Sends an email to each subscriber via SendGrid (requires SENDGRID_API_KEY secret).
 *   4. Updates newsletter status → "sent" with recipientCount.
 *
 * Setup (human task):
 *   firebase functions:secrets:set SENDGRID_API_KEY
 *   npm install @sendgrid/mail  (inside functions/)
 *   firebase deploy --only functions:onNewsletterSend
 */

import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";

const sendgridApiKey = defineSecret("SENDGRID_API_KEY");

interface NewsletterDoc {
  title: string;
  body: string;
  authorName: string;
  audience: string;
  category: string;
  status: string;
}

interface SubscriptionDoc {
  userId: string;
  email: string;
  isSubscribed: boolean;
  subscribedCategories: string[];
}

async function resolveRecipients(
  db: admin.firestore.Firestore,
  audience: string,
  category: string
): Promise<string[]> {
  const snap = await db
    .collection("newsletter_subscriptions")
    .where("isSubscribed", "==", true)
    .get();

  const emails: string[] = [];
  for (const doc of snap.docs) {
    const sub = doc.data() as SubscriptionDoc;
    if (!sub.email || !sub.subscribedCategories?.includes(category)) continue;

    // audience filter
    if (audience === "allUsers") {
      emails.push(sub.email);
    } else if (audience === "premiumUsers") {
      // Check user plan — only add premium users
      const userDoc = await db.collection("users").doc(sub.userId).get();
      const plan = userDoc.data()?.planType ?? "free";
      if (plan === "premium" || plan === "enterprise") {
        emails.push(sub.email);
      }
    } else {
      // vehicleOwners, shopFollowers — add all subscribed (refine as needed)
      emails.push(sub.email);
    }
  }
  return emails;
}

/**
 * Firestore-triggered Cloud Function.
 * Fires when any newsletter document is written.
 * Only processes documents transitioning to status=="scheduled".
 */
export const onNewsletterSend = onDocumentWritten(
  {
    document: "newsletters/{newsletterId}",
    secrets: [sendgridApiKey],
    region: "asia-northeast1",
  },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return; // deleted — skip

    const data = after.data() as NewsletterDoc;
    if (data.status !== "scheduled") return; // not queued — skip

    const db = admin.firestore();
    const newsletterId = event.params.newsletterId;

    try {
      const recipients = await resolveRecipients(
        db,
        data.audience,
        data.category
      );

      if (recipients.length > 0) {
        // Dynamic import so the module is optional during local dev without the secret
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const sgMail = require("@sendgrid/mail");
        sgMail.setApiKey(sendgridApiKey.value());

        const messages = recipients.map((to) => ({
          to,
          from: "no-reply@trustcar.jp",
          subject: data.title,
          text: data.body,
          html: `<p>${data.body.replace(/\n/g, "<br>")}</p>
                 <hr>
                 <small>配信停止は <a href="https://app.trustcar.jp/unsubscribe">こちら</a></small>`,
        }));

        // SendGrid supports batch send via an array
        await sgMail.send(messages);
      }

      // Mark as sent
      await db.collection("newsletters").doc(newsletterId).update({
        status: "sent",
        sentAt: admin.firestore.Timestamp.fromDate(new Date()),
        recipientCount: recipients.length,
        updatedAt: admin.firestore.Timestamp.fromDate(new Date()),
      });
    } catch (err) {
      console.error(`Failed to send newsletter ${newsletterId}:`, err);
      // Revert status to draft so the author can retry
      await db.collection("newsletters").doc(newsletterId).update({
        status: "draft",
        updatedAt: admin.firestore.Timestamp.fromDate(new Date()),
      });
    }
  }
);
