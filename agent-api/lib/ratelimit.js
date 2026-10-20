/**
 * In-Memory Rate Limiter
 * 
 * Enforces per user UID:
 * - 20 requests per minute
 * - 200 requests per day
 * 
 * Note: Since Firestore rate_limits collection cannot be written by ordinary users
 * without relaxing security rules, this uses an in-memory Map. It operates on a
 * best-effort basis per serverless container instance.
 */

const MAX_PER_MINUTE = 20;
const MAX_PER_DAY = 200;

// uid -> { minuteWindow, minuteCount, dayWindow, dayCount }
const memoryStore = new Map();

function checkRateLimit(uid) {
  if (!uid) {
    return { allowed: true };
  }

  const now = Date.now();
  const currentMinuteWindow = Math.floor(now / 60000);
  const currentDayWindow = Math.floor(now / 86400000);

  let record = memoryStore.get(uid);
  if (!record) {
    record = {
      minuteWindow: currentMinuteWindow,
      minuteCount: 0,
      dayWindow: currentDayWindow,
      dayCount: 0,
    };
    memoryStore.set(uid, record);
  }

  // Reset minute window if elapsed
  if (record.minuteWindow !== currentMinuteWindow) {
    record.minuteWindow = currentMinuteWindow;
    record.minuteCount = 0;
  }

  // Reset day window if elapsed
  if (record.dayWindow !== currentDayWindow) {
    record.dayWindow = currentDayWindow;
    record.dayCount = 0;
  }

  if (record.minuteCount >= MAX_PER_MINUTE) {
    const retryAfterSeconds = 60 - Math.floor((now % 60000) / 1000);
    return {
      allowed: false,
      retryAfter: Math.max(1, retryAfterSeconds),
      reason: "Rate limit exceeded: maximum 20 requests per minute.",
    };
  }

  if (record.dayCount >= MAX_PER_DAY) {
    return {
      allowed: false,
      retryAfter: 3600,
      reason: "Daily limit exceeded: maximum 200 requests per day.",
    };
  }

  record.minuteCount += 1;
  record.dayCount += 1;

  // Cleanup old entries if map grows too large (> 10,000 users)
  if (memoryStore.size > 10000) {
    for (const [k, v] of memoryStore.entries()) {
      if (v.dayWindow !== currentDayWindow) {
        memoryStore.delete(k);
      }
    }
  }

  return { allowed: true };
}

function _resetMemoryStore() {
  memoryStore.clear();
}

function _getMemoryStore() {
  return memoryStore;
}

module.exports = {
  MAX_PER_MINUTE,
  MAX_PER_DAY,
  checkRateLimit,
  _resetMemoryStore,
  _getMemoryStore,
};
