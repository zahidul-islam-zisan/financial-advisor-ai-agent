/**
 * Financial Action Cancellation Endpoint
 * POST /api/cancel
 * Body: { actionId: string }
 * Headers: Authorization: Bearer <Firebase ID token>
 */
const { admin } = require("../lib/db");
const { handleCors, authenticateRequest } = require("../lib/auth");
const { getDb } = require("../lib/db");

module.exports = async function handler(req, res) {
  if (handleCors(req, res)) return;

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed. Use POST." });
    return;
  }

  // 1. Authenticate request via Firebase ID token
  const auth = await authenticateRequest(req, res);
  if (!auth) return;

  const { uid, docId } = auth;
  const { actionId } = req.body || {};

  if (!actionId || typeof actionId !== "string" || actionId.trim().length === 0) {
    res.status(400).json({ error: "Invalid request: 'actionId' is required." });
    return;
  }

  const db = getDb();
  if (!db) {
    res.status(500).json({ error: "Database service unavailable." });
    return;
  }

  const actionRef = db.collection("users").doc(docId).collection("pending_actions").doc(actionId.trim());

  try {
    const result = await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(actionRef);
      if (!snap.exists) {
        return { errorStatus: 404, message: "Pending action not found." };
      }

      const action = snap.data();

      // Security Check: Ownership
      if (action.uid !== uid) {
        return { errorStatus: 403, message: "Forbidden: You do not own this pending action." };
      }

      if (action.status !== "PENDING") {
        return { errorStatus: 400, message: `Action cannot be cancelled (status: ${action.status}).` };
      }

      const nowTimestamp = admin.firestore.Timestamp.now();

      // Write Cancellation Audit Record
      const auditLogRef = db.collection("users").doc(docId).collection("audit_logs").doc();
      transaction.set(auditLogRef, {
        id: auditLogRef.id,
        uid,
        docId,
        actionId: actionId.trim(),
        actionType: action.actionType || "UNKNOWN",
        status: "CANCELLED",
        summary: `User explicitly cancelled proposed action: ${action.title || actionId}`,
        details: action.parameters || {},
        timestamp: nowTimestamp,
        verifiedByServer: true,
      });

      // Update pending action to REJECTED
      transaction.update(actionRef, {
        status: "REJECTED",
        cancelledAt: nowTimestamp,
        auditLogId: auditLogRef.id,
      });

      return { success: true };
    });

    if (result.errorStatus) {
      res.status(result.errorStatus).json({ error: result.message });
      return;
    }

    res.status(200).json(result);
  } catch (err) {
    console.error("Action cancellation transaction error:", err.message);
    res.status(500).json({ error: "Failed to cancel financial action." });
  }
};
