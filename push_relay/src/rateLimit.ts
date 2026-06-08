// Per-source-IP rate limiting so one abuser cannot starve other deployments. A fixed-window counter
// is enough here: one home/deployment is roughly one public IP, and limits are generous to tolerate
// the occasional CGNAT-shared IP. The counter is the only state the relay keeps and it lives in
// Firestore (within the free tier at this volume); the windowing logic itself is pure and tested.

export interface RateLimitOptions {
  // Maximum number of allowed calls within a window.
  limit: number;
  // Window length in milliseconds.
  windowMs: number;
}

// Generous defaults: an OOTT deployment only pushes on network-membership changes, so a few hundred
// per hour is far above normal while still capping a runaway/abusive source.
export const DEFAULT_RATE_LIMIT: RateLimitOptions = {
  limit: 300,
  windowMs: 60 * 60 * 1000,
};

// Atomic per-key counter. `hit` records one call against `key` and returns the running count within
// the current window, starting a fresh window when the previous one has elapsed.
export interface RateLimitStore {
  hit(key: string, windowMs: number, now: number): Promise<number>;
}

export interface RateLimitDecision {
  allowed: boolean;
  count: number;
}

export async function checkRateLimit(
  store: RateLimitStore,
  key: string,
  options: RateLimitOptions = DEFAULT_RATE_LIMIT,
  now: number = Date.now(),
): Promise<RateLimitDecision> {
  const count = await store.hit(key, options.windowMs, now);
  return { allowed: count <= options.limit, count };
}

interface WindowState {
  count: number;
  windowStart: number;
}

// Compute the next window state from the previous one. A call in a new window resets the counter.
function nextWindow(previous: WindowState | null, windowMs: number, now: number): WindowState {
  if (previous && now - previous.windowStart < windowMs) {
    return { count: previous.count + 1, windowStart: previous.windowStart };
  }
  return { count: 1, windowStart: now };
}

// In-memory store for unit tests and the local emulator. Not for production (a Cloud Function scales
// to many instances, so the counter must be shared — see the Firestore store below).
export class InMemoryRateLimitStore implements RateLimitStore {
  private readonly windows = new Map<string, WindowState>();

  async hit(key: string, windowMs: number, now: number): Promise<number> {
    const state = nextWindow(this.windows.get(key) ?? null, windowMs, now);
    this.windows.set(key, state);
    return state.count;
  }
}

// Structural slice of the Firestore API the store needs, so this module does not depend on
// firebase-admin and stays unit-testable.
interface DocSnapshotLike {
  exists: boolean;
  data(): WindowState | undefined;
}
interface DocRefLike {
  readonly path: string;
}
interface TransactionLike {
  get(ref: DocRefLike): Promise<DocSnapshotLike>;
  set(ref: DocRefLike, data: WindowState): void;
}
interface CollectionLike {
  doc(id: string): DocRefLike;
}
export interface FirestoreLike {
  collection(name: string): CollectionLike;
  runTransaction<T>(updateFunction: (transaction: TransactionLike) => Promise<T>): Promise<T>;
}

// Firestore-backed store. The read-modify-write runs in a transaction so concurrent function
// instances increment the same counter atomically.
export function createFirestoreRateLimitStore(
  db: FirestoreLike,
  collection = "rate_limits",
): RateLimitStore {
  return {
    hit(key: string, windowMs: number, now: number): Promise<number> {
      // Document ids cannot contain "/"; IPv6 addresses are clean but encode defensively anyway.
      const ref = db.collection(collection).doc(encodeURIComponent(key));
      return db.runTransaction(async (tx) => {
        const snapshot = await tx.get(ref);
        const previous = snapshot.exists ? (snapshot.data() ?? null) : null;
        const state = nextWindow(previous, windowMs, now);
        tx.set(ref, state);
        return state.count;
      });
    },
  };
}
