import {
  classifyFailure,
  MAX_BODY_LENGTH,
  MAX_TITLE_LENGTH,
  MAX_TOKENS,
  sendPush,
  validatePushRequest,
  type BatchResponseLike,
  type MessengerLike,
  type TokenMessage,
} from "./push";

describe("validatePushRequest", () => {
  const valid = {
    tokens: ["token-a", "token-b"],
    notification: { title: "New device", body: "A new device joined your network" },
  };

  it("accepts a well-formed request", () => {
    const result = validatePushRequest(valid);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.tokens).toEqual(["token-a", "token-b"]);
      expect(result.value.notification.title).toBe("New device");
    }
  });

  it.each([
    ["a non-object body", 42],
    ["a null body", null],
  ])("rejects %s", (_label, body) => {
    expect(validatePushRequest(body).ok).toBe(false);
  });

  it("rejects a missing or empty token list", () => {
    expect(validatePushRequest({ ...valid, tokens: undefined }).ok).toBe(false);
    expect(validatePushRequest({ ...valid, tokens: [] }).ok).toBe(false);
  });

  it("rejects more than the maximum number of tokens", () => {
    const tokens = new Array(MAX_TOKENS + 1).fill("t");
    expect(validatePushRequest({ ...valid, tokens }).ok).toBe(false);
  });

  it("rejects non-string or empty tokens", () => {
    expect(validatePushRequest({ ...valid, tokens: ["ok", 1] }).ok).toBe(false);
    expect(validatePushRequest({ ...valid, tokens: ["ok", ""] }).ok).toBe(false);
  });

  it("rejects a missing notification or empty fields", () => {
    expect(validatePushRequest({ tokens: valid.tokens }).ok).toBe(false);
    expect(
      validatePushRequest({ ...valid, notification: { title: "", body: "b" } }).ok,
    ).toBe(false);
    expect(
      validatePushRequest({ ...valid, notification: { title: "t", body: "" } }).ok,
    ).toBe(false);
  });

  it("rejects oversized title or body", () => {
    expect(
      validatePushRequest({
        ...valid,
        notification: { title: "t".repeat(MAX_TITLE_LENGTH + 1), body: "b" },
      }).ok,
    ).toBe(false);
    expect(
      validatePushRequest({
        ...valid,
        notification: { title: "t", body: "b".repeat(MAX_BODY_LENGTH + 1) },
      }).ok,
    ).toBe(false);
  });
});

describe("classifyFailure", () => {
  it("maps not-registered to unregistered", () => {
    expect(classifyFailure("messaging/registration-token-not-registered")).toBe("unregistered");
  });

  it("maps malformed-token codes to invalid", () => {
    expect(classifyFailure("messaging/invalid-registration-token")).toBe("invalid");
    expect(classifyFailure("messaging/invalid-argument")).toBe("invalid");
    expect(classifyFailure("messaging/mismatched-credential")).toBe("invalid");
  });

  it("treats unknown or missing codes as transient errors", () => {
    expect(classifyFailure("messaging/internal-error")).toBe("error");
    expect(classifyFailure(undefined)).toBe("error");
  });
});

describe("sendPush", () => {
  function messengerReturning(batch: BatchResponseLike): {
    messenger: MessengerLike;
    sent: TokenMessage[][];
  } {
    const sent: TokenMessage[][] = [];
    return {
      sent,
      messenger: {
        async sendEach(messages: TokenMessage[]) {
          sent.push(messages);
          return batch;
        },
      },
    };
  }

  it("maps each response to its token in order", async () => {
    const { messenger, sent } = messengerReturning({
      responses: [
        { success: true },
        { success: false, error: { code: "messaging/registration-token-not-registered" } },
        { success: false, error: { code: "messaging/invalid-argument" } },
        { success: false, error: { code: "messaging/internal-error" } },
      ],
    });

    const results = await sendPush(messenger, {
      tokens: ["ok", "gone", "bad", "flaky"],
      notification: { title: "t", body: "b" },
    });

    expect(results).toEqual([
      { token: "ok", status: "ok" },
      { token: "gone", status: "unregistered" },
      { token: "bad", status: "invalid" },
      { token: "flaky", status: "error" },
    ]);
    // Only the sanitized title/body is forwarded — no data payload.
    expect(sent[0][0]).toEqual({ token: "ok", notification: { title: "t", body: "b" } });
  });

  it("defaults to a transient error when a response entry is missing", async () => {
    const { messenger } = messengerReturning({ responses: [] });
    const results = await sendPush(messenger, {
      tokens: ["lonely"],
      notification: { title: "t", body: "b" },
    });
    expect(results).toEqual([{ token: "lonely", status: "error" }]);
  });
});
