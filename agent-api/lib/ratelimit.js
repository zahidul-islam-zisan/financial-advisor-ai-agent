/**
 * Rate Limiter using Firestore
 * Enforces:
 * - 20 requests per minute
 * - 200 requests per day
 * Per user UID in `rate_limits/{uid}`
 */

const MAX_PER_MINUTE = 20;
const MAX_PER_DAY = 200;

async function checkRateLimit(db, uid) {
  if (!db || !uid) {
    // If running in test mode without db, allow by default
    return { allowed: true };
  }

  const rateLimitRef = db.collection("rate_limits").doc(uid);
  const now = Date.now();
  const currentMinuteWindow = Math.floor(now / 60000);
  const currentDayWindow = Math.floor(now / 86400000);

  try {
    const result = await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(rateLimitRef);
      const data = doc.exists ? doc.data() : {};

      let minuteCount = data.minuteWindow === currentMinuteWindow ? (data.minuteCount || 0) : 0;
      let dayCount = data.dayWindow === currentDayWindow ? (data.dayCount || 0) : 0;

      if (minuteCount >= MAX_PER_MINUTE) {
        const retryAfterSeconds = 60 - Math.floor((now % 60000) / 1000);
        return {
          allowed: false,
          retryAfter: retryAfterSeconds,
          reason: "Rate limit exceeded: maximum 20 requests per minute.",
        };
      }

      if (dayCount >= MAX_PER_DAY) {
        return {
          allowed: false,
          retryAfter: 3600,
          reason: "Daily limit exceeded: maximum 200 requests per day.",
        };
      }

      minuteCount += 1;
      dayCount += 1;

      transaction.set(rateLimitRef, {
        minuteWindow: currentMinuteWindow,
        minuteCount,
        dayWindow: currentDayWindow,
        dayCount,
        lastRequestAt: now,
      }, { merge: true });

      return { allowed: true };
    });

    return result;
  } catch (err) {
    console.error("Rate limiter check error:", err.message);
    // Fail open in unexpected DB glitch so users aren't locked out, but log error
    return { allowed: true };
  }
}

module.exports = {
  MAX_PER_MINUTE,
  MAX_PER_DAY,
  checkRateLimit,
};
