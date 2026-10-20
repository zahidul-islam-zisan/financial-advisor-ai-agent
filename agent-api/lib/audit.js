/**
 * Server-Side Audit Logger
 * Writes tamper-evident records to users/{docId}/audit_logs/{id}
 */
const { admin } = require("./db");

async function logAudit(db, { uid, docId, actionId = null, actionType, status, summary, details = {} }) {
  if (!db || !docId) {
    return null;
  }

  try {
    // Sanitize details: ensure no tokens, keys, or raw full texts are recorded
    const sanitizedDetails = { ...details };
    delete sanitizedDetails.token;
    delete sanitizedDetails.apiKey;
    delete sanitizedDetails.password;
    delete sanitizedDetails.rawResponse;

    const logRef = db.collection("users").doc(docId).collection("audit_logs").doc();
    const now = (admin && admin.firestore && admin.firestore.Timestamp)
      ? admin.firestore.Timestamp.now()
      : new Date();

    const record = {
      id: logRef.id,
      uid,
      docId,
      actionId,
      actionType,
      status, // SUCCESS, FAILED, CANCELLED, REJECTED
      summary: summary || "",
      details: sanitizedDetails,
      timestamp: now,
      verifiedByServer: true,
    };

    await logRef.set(record);
    return record;
  } catch (err) {
    console.error("Failed to write audit log:", err.message);
    return null;
  }
}

module.exports = {
  logAudit,
};
