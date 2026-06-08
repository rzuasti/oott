import express, { type Express, type Request, type Response } from "express";

import { sendPush, validatePushRequest, type MessengerLike } from "./push";
import {
  checkRateLimit,
  DEFAULT_RATE_LIMIT,
  type RateLimitOptions,
  type RateLimitStore,
} from "./rateLimit";

export interface AppDependencies {
  messenger: MessengerLike;
  rateLimitStore: RateLimitStore;
  rateLimit?: RateLimitOptions;
}

// Identify the caller for rate limiting. Behind Cloud Functions the real client IP is the left-most
// entry of X-Forwarded-For (Google's proxy appends its own); `trust proxy` makes `req.ip` resolve to
// it. One home/deployment is roughly one public IP.
function clientKey(req: Request): string {
  return req.ip ?? "unknown";
}

// Build the relay HTTP app. Dependencies are injected so the routes can be exercised with a fake
// messenger and an in-memory rate-limit store in tests, and with the real Firebase ones in
// production (see index.ts).
export function createApp(deps: AppDependencies): Express {
  const app = express();
  // Trust Google's front-end proxy so req.ip is the caller, not the proxy.
  app.set("trust proxy", true);
  app.use(express.json({ limit: "256kb" }));

  // Liveness probe — no side effects, never rate limited.
  app.get("/healthz", (_req: Request, res: Response) => {
    res.status(200).send("ok");
  });

  app.post("/v1/push", async (req: Request, res: Response) => {
    try {
      const decision = await checkRateLimit(
        deps.rateLimitStore,
        clientKey(req),
        deps.rateLimit ?? DEFAULT_RATE_LIMIT,
      );
      if (!decision.allowed) {
        res.status(429).json({ error: "rate limit exceeded" });
        return;
      }

      const validation = validatePushRequest(req.body);
      if (!validation.ok) {
        res.status(400).json({ error: validation.error });
        return;
      }

      const results = await sendPush(deps.messenger, validation.value);
      res.status(200).json({ results });
    } catch (err) {
      // A messenger/transport failure is upstream's fault, not the caller's.
      const message = err instanceof Error ? err.message : "unknown error";
      console.error("Failed to relay push:", message);
      res.status(502).json({ error: "failed to deliver to FCM" });
    }
  });

  return app;
}
