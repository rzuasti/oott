import {
  checkRateLimit,
  createFirestoreRateLimitStore,
  InMemoryRateLimitStore,
  type FirestoreLike,
} from "./rateLimit";

describe("checkRateLimit", () => {
  const options = { limit: 3, windowMs: 1000 };

  it("allows calls up to the limit then blocks within the window", async () => {
    const store = new InMemoryRateLimitStore();
    const now = 10_000;

    for (let i = 1; i <= options.limit; i++) {
      const decision = await checkRateLimit(store, "1.2.3.4", options, now);
      expect(decision.allowed).toBe(true);
      expect(decision.count).toBe(i);
    }

    const blocked = await checkRateLimit(store, "1.2.3.4", options, now);
    expect(blocked.allowed).toBe(false);
    expect(blocked.count).toBe(options.limit + 1);
  });

  it("starts a fresh window once the window has elapsed", async () => {
    const store = new InMemoryRateLimitStore();

    await checkRateLimit(store, "1.2.3.4", options, 0);
    await checkRateLimit(store, "1.2.3.4", options, 500);
    const blocked = await checkRateLimit(store, "1.2.3.4", options, 900);
    expect(blocked.count).toBe(3);

    // Past the window: the counter resets.
    const fresh = await checkRateLimit(store, "1.2.3.4", options, 1100);
    expect(fresh.allowed).toBe(true);
    expect(fresh.count).toBe(1);
  });

  it("tracks each source key independently", async () => {
    const store = new InMemoryRateLimitStore();
    const a = await checkRateLimit(store, "1.1.1.1", options, 0);
    const b = await checkRateLimit(store, "2.2.2.2", options, 0);
    expect(a.count).toBe(1);
    expect(b.count).toBe(1);
  });
});

describe("createFirestoreRateLimitStore", () => {
  // A tiny in-memory stand-in for the Firestore transaction surface the store uses.
  function fakeFirestore(): FirestoreLike {
    const docs = new Map<string, { count: number; windowStart: number }>();
    return {
      collection() {
        return {
          doc(id: string) {
            return { path: id };
          },
        };
      },
      async runTransaction(fn) {
        const tx = {
          async get(ref: { path: string }) {
            const data = docs.get(ref.path);
            return { exists: data !== undefined, data: () => data };
          },
          set(ref: { path: string }, data: { count: number; windowStart: number }) {
            docs.set(ref.path, data);
          },
        };
        return fn(tx);
      },
    };
  }

  it("persists and increments the per-key counter transactionally", async () => {
    const store = createFirestoreRateLimitStore(fakeFirestore());
    expect(await store.hit("9.9.9.9", 1000, 0)).toBe(1);
    expect(await store.hit("9.9.9.9", 1000, 100)).toBe(2);
    // New window resets the count.
    expect(await store.hit("9.9.9.9", 1000, 2000)).toBe(1);
  });
});
