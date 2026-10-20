/**
 * Financial Action Cancellation Endpoint
 * POST /api/cancel
 * Body: { actionId: string }
 * Headers: Authorization: Bearer <Firebase ID token>
 */
const { randomUUID } = require("crypto");
const { handleCors, authenticateRequest } = require("../lib/auth");
const { FirestoreRestClient, toFirestoreFields } = require("../lib/db");

module.exports = async function handler(req, res) {
  if (handleCors(req, res)) return;

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed. Use POST." });
    return;
  }

  // 1. Authenticate request via Firebase ID token
  const auth = await authenticateRequest(req, res);
  if (!auth) return;

  const { uid, docId, idToken } = auth;
  const { actionId } = req.body || {};

  if (!actionId || typeof actionId !== "string" || actionId.trim().length === 0) {
    res.status(400).json({ error: "Invalid request: 'actionId' is required." });
    return;
  }

  const client = new FirestoreRestClient({
    idToken,
    projectId: process.env.FIREBASE_PROJECT_ID,
  });

  const encodedDocId = encodeURIComponent(docId);
  const cleanActionId = actionId.trim();
  const pendingActionPath = `users/${encodedDocId}/pending_actions/${cleanActionId}`;

  try {
    const pendingDoc = await client.getDoc(pendingActionPath);
    if (!pendingDoc || !pendingDoc.fields) {
      res.status(404).json({ error: "Pending action not found." });
      return;
    }

    const action = pendingDoc.fields;

    // Security Check: Ownership
    if (action.uid !== uid) {
      res.status(403).json({ error: "Forbidden: You do not own this pending action." });
      return;
    }

    if (action.status !== "PENDING") {
      res.status(400).json({ error: `Action cannot be cancelled (status: ${action.status}).` });
      return;
    }

    const now = new Date();
    const auditLogId = randomUUID();
    const auditDocPath = `users/${encodedDocId}/audit_logs/${auditLogId}`;

    const writes = [
      // 1. Update pending action to REJECTED with updateTime precondition
      {
        update: {
          name: client.docResourceName(pendingActionPath),
          fields: {
            status: { stringValue: "REJECTED" },
            cancelledAt: { timestampValue: now.toISOString() },
            auditLogId: { stringValue: auditLogId },
          },
        },
        updateMask: {
          fieldPaths: ["status", "cancelledAt", "auditLogId"],
        },
        currentDocument: {
          updateTime: pendingDoc.updateTime,
        },
      },
      // 2. Write audit log
      {
        update: {
          name: client.docResourceName(auditDocPath),
          fields: toFirestoreFields({
            id: auditLogId,
            uid,
            docId,
            actionId: cleanActionId,
            actionType: action.actionType || "UNKNOWN",
            status: "CANCELLED",
            summary: `User explicitly cancelled proposed action: ${action.title || cleanActionId}`,
            details: action.parameters || {},
            timestamp: now,
            writtenViaAgentApi: true,
          }),
        },
      },
    ];

    await client.commit(writes);

    res.status(200).json({ success: true });
  } catch (err) {
    console.error("Action cancellation commit error:", err.message);
    const msg = (err.message || "").toLowerCase();
    if (msg.includes("precondition") || msg.includes("already") || msg.includes("conflict")) {
      res.status(409).json({ error: "Action already processed. Replay blocked." });
      return;
    }
    if (msg.includes("permission denied") || msg.includes("403")) {
      res.status(403).json({ error: "Permission denied by security rules." });
      return;
    }
    res.status(500).json({ error: "Failed to cancel financial action." });
  }
};
