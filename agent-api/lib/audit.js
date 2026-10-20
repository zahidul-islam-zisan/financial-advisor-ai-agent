/**
 * Audit Logger
 * Writes audit records to users/{docId}/audit_logs/{id}
 * Uses FirestoreRestClient to write directly with user's ID token.
 */

const { randomUUID } = require("crypto");

async function logAudit(client, { uid, docId, actionId = null, actionType, status, summary, details = {} }) {
  if (!client || !docId) {
    return null;
  }

  try {
    const sanitizedDetails = { ...details };
    delete sanitizedDetails.token;
    delete sanitizedDetails.apiKey;
    delete sanitizedDetails.password;
    delete sanitizedDetails.rawResponse;

    const logId = randomUUID();
    const record = {
      id: logId,
      uid,
      docId,
      actionId,
      actionType,
      status, // SUCCESS, FAILED, CANCELLED, REJECTED
      summary: summary || "",
      details: sanitizedDetails,
      timestamp: new Date(),
      writtenViaAgentApi: true,
    };

    await client.createDoc(
      `users/${encodeURIComponent(docId)}`,
      "audit_logs",
      logId,
      record
    );

    return record;
  } catch (err) {
    console.error("Failed to write audit log:", err.message);
    return null;
  }
}

module.exports = {
  logAudit,
};
