import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onRequest } from "firebase-functions/v2/https";

import { createApp } from "./app";
import { createFirestoreRateLimitStore, type FirestoreLike } from "./rateLimit";
import type { MessengerLike, TokenMessage } from "./push";

// One Admin SDK app per function instance. It authenticates to FCM via the function's runtime
// service account — there is no service-account JSON to manage, store, or rotate (Google keeps the
// secret).
initializeApp();

// Adapt the Admin Messaging API to the small MessengerLike surface the handler depends on.
const messenger: MessengerLike = {
  sendEach(messages: TokenMessage[]) {
    return getMessaging().sendEach(messages);
  },
};

const rateLimitStore = createFirestoreRateLimitStore(
  getFirestore() as unknown as FirestoreLike,
);

const app = createApp({ messenger, rateLimitStore });

// Single HTTP function hosting both routes (POST /v1/push, GET /health). Scales to zero, so there
// is no idle cost and no server/OS to patch; the platform provides TLS and a stable HTTPS URL.
export const relay = onRequest({ region: "us-central1", maxInstances: 10 }, app);
