// Core push logic, kept free of Firebase wiring so it can be unit-tested with a mock messenger.
// The relay forwards only an already-sanitized title/body — never a `data` payload, MAC or IP
// (see ../push_notifications.md, "No private data in payloads").

// Status reported back to the caller for each token so it can prune dead ones.
// `ok`           – delivered (or accepted by FCM).
// `unregistered` – the app was uninstalled / the token expired; prune it.
// `invalid`      – the token is malformed or for another project; prune it.
// `error`        – a transient failure; keep the token and retry on the next event.
export type TokenStatus = "ok" | "unregistered" | "invalid" | "error";

export interface PushNotification {
  title: string;
  body: string;
}

export interface PushRequest {
  tokens: string[];
  notification: PushNotification;
}

export interface TokenResult {
  token: string;
  status: TokenStatus;
}

// A single message handed to the messenger — mirrors the shape of `admin.messaging.TokenMessage`.
export interface TokenMessage {
  token: string;
  notification: PushNotification;
}

// Minimal slice of `admin.messaging.Messaging` we depend on, so tests can supply a fake.
export interface BatchResponseLike {
  responses: Array<{ success: boolean; error?: { code?: string } }>;
}

export interface MessengerLike {
  sendEach(messages: TokenMessage[]): Promise<BatchResponseLike>;
}

// FCM caps a single `sendEach` multicast at 500 messages; a single OOTT deployment has far fewer
// devices, so this doubles as request-size protection.
export const MAX_TOKENS = 500;
export const MAX_TITLE_LENGTH = 256;
export const MAX_BODY_LENGTH = 2048;

export type ValidationResult =
  | { ok: true; value: PushRequest }
  | { ok: false; error: string };

// Validate and narrow an untrusted request body. Rejects anything malformed or oversized so the
// relay never forwards junk to FCM (and a bad caller cannot run up cost with huge payloads).
export function validatePushRequest(body: unknown): ValidationResult {
  if (typeof body !== "object" || body === null) {
    return { ok: false, error: "body must be a JSON object" };
  }
  const candidate = body as Record<string, unknown>;

  const tokens = candidate.tokens;
  if (!Array.isArray(tokens) || tokens.length === 0) {
    return { ok: false, error: "tokens must be a non-empty array" };
  }
  if (tokens.length > MAX_TOKENS) {
    return { ok: false, error: `tokens must contain at most ${MAX_TOKENS} entries` };
  }
  if (!tokens.every((token) => typeof token === "string" && token.length > 0)) {
    return { ok: false, error: "every token must be a non-empty string" };
  }

  const notification = candidate.notification;
  if (typeof notification !== "object" || notification === null) {
    return { ok: false, error: "notification must be an object" };
  }
  const { title, body: messageBody } = notification as Record<string, unknown>;
  if (typeof title !== "string" || title.length === 0) {
    return { ok: false, error: "notification.title must be a non-empty string" };
  }
  if (typeof messageBody !== "string" || messageBody.length === 0) {
    return { ok: false, error: "notification.body must be a non-empty string" };
  }
  if (title.length > MAX_TITLE_LENGTH) {
    return { ok: false, error: `notification.title must be at most ${MAX_TITLE_LENGTH} characters` };
  }
  if (messageBody.length > MAX_BODY_LENGTH) {
    return { ok: false, error: `notification.body must be at most ${MAX_BODY_LENGTH} characters` };
  }

  return {
    ok: true,
    value: { tokens: tokens as string[], notification: { title, body: messageBody } },
  };
}

// Map an FCM error code to the status the backend uses to decide whether to prune the token.
export function classifyFailure(code: string | undefined): TokenStatus {
  switch (code) {
    case "messaging/registration-token-not-registered":
      return "unregistered";
    case "messaging/invalid-registration-token":
    case "messaging/invalid-argument":
    case "messaging/mismatched-credential":
      return "invalid";
    default:
      return "error";
  }
}

// Send one notification to every token and return a per-token result. Order is preserved so each
// response lines up with its token. `sendEach` never throws for per-token failures — they surface as
// unsuccessful entries — so only an outright messenger error propagates to the caller.
export async function sendPush(
  messenger: MessengerLike,
  request: PushRequest,
): Promise<TokenResult[]> {
  const messages: TokenMessage[] = request.tokens.map((token) => ({
    token,
    notification: request.notification,
  }));

  const batch = await messenger.sendEach(messages);

  return request.tokens.map((token, index) => {
    const response = batch.responses[index];
    if (response && response.success) {
      return { token, status: "ok" };
    }
    return { token, status: classifyFailure(response?.error?.code) };
  });
}
