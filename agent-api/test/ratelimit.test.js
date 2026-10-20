const { describe, it, beforeEach } = require("node:test");
const assert = require("node:assert");
const {
  checkRateLimit,
  _resetMemoryStore,
  _getMemoryStore,
  MAX_PER_MINUTE,
  MAX_PER_DAY,
} = require("../lib/ratelimit");

describe("In-Memory Rate Limiter", () => {
  beforeEach(() => {
    _resetMemoryStore();
  });

  it("allows up to 20 requests per minute and blocks the 21st", () => {
    const uid = "test_user_minute";

    for (let i = 1; i <= MAX_PER_MINUTE; i++) {
      const result = checkRateLimit(uid);
      assert.strictEqual(result.allowed, true, `Request ${i} should be allowed`);
    }

    const blocked = checkRateLimit(uid);
    assert.strictEqual(blocked.allowed, false);
    assert.match(blocked.reason, /20 requests per minute/);
    assert.strictEqual(typeof blocked.retryAfter, "number");
    assert.strictEqual(blocked.retryAfter >= 1, true);
  });

  it("allows up to 200 requests per day and blocks the 201st", () => {
    const uid = "test_user_day";
    const store = _getMemoryStore();
    const now = Date.now();
    const currentDayWindow = Math.floor(now / 86400000);
    const currentMinuteWindow = Math.floor(now / 60000);

    // Set dayCount to 200 (limit reached) but with minuteCount at 0
    store.set(uid, {
      minuteWindow: currentMinuteWindow,
      minuteCount: 0,
      dayWindow: currentDayWindow,
      dayCount: MAX_PER_DAY,
    });

    const blocked = checkRateLimit(uid);
    assert.strictEqual(blocked.allowed, false);
    assert.match(blocked.reason, /200 requests per day/);
    assert.strictEqual(blocked.retryAfter, 3600);
  });

  it("isolates rate limits between different users", () => {
    const userA = "user_a";
    const userB = "user_b";

    for (let i = 1; i <= MAX_PER_MINUTE; i++) {
      checkRateLimit(userA);
    }

    // User A should be blocked
    assert.strictEqual(checkRateLimit(userA).allowed, false);
    // User B should still be allowed
    assert.strictEqual(checkRateLimit(userB).allowed, true);
  });

  it("allows requests when uid is missing (bypass)", () => {
    assert.strictEqual(checkRateLimit(null).allowed, true);
    assert.strictEqual(checkRateLimit("").allowed, true);
  });
});
