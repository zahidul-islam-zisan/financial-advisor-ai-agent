/**
 * 2-Step Financial Action Confirmation Endpoint
 * POST /api/confirm
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

  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    res.status(500).json({ error: "Internal server error: configuration missing." });
    return;
  }

  const client = new FirestoreRestClient({
    idToken,
    projectId,
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

    // Security Check 1: User ownership
    if (action.uid !== uid) {
      res.status(403).json({ error: "Forbidden: You do not own this pending action." });
      return;
    }

    // Security Check 2: Anti-replay protection
    if (action.status !== "PENDING") {
      res.status(409).json({
        error: `Action already processed (${action.status}). Replay blocked.`,
      });
      return;
    }

    // Security Check 3: Expiration check
    const nowMs = Date.now();
    const expiresAtMs = action.expiresAt ? new Date(action.expiresAt).getTime() : 0;

    if (expiresAtMs && nowMs > expiresAtMs) {
      try {
        await client.commit([
          {
            update: {
              name: client.docResourceName(pendingActionPath),
              fields: { status: { stringValue: "EXPIRED" } },
            },
            updateMask: { fieldPaths: ["status"] },
            currentDocument: { updateTime: pendingDoc.updateTime },
          },
        ]);
      } catch (_) {
        // Ignore precondition error if already updated
      }
      res.status(410).json({ error: "Pending action has expired. Please ask the AI to propose it again." });
      return;
    }

    const now = new Date();
    let executionSummary = "";
    const writes = [];

    // Trusted Execution based on Action Type
    if (action.actionType === "CREATE_BUDGET") {
      const category = (action.parameters && action.parameters.category) || "";
      const limit = Number(action.parameters && action.parameters.limit);
      if (!category || isNaN(limit) || limit <= 0) {
        res.status(400).json({ error: "Invalid budget parameters in pending action." });
        return;
      }

      const categorySlug = category.toLowerCase().replace(/\s+/g, "_");
      const budgetDocPath = `users/${encodedDocId}/budgets/${categorySlug}`;

      writes.push({
        update: {
          name: client.docResourceName(budgetDocPath),
          fields: toFirestoreFields({
            category,
            limit,
            updatedAt: now,
            createdAt: now,
          }),
        },
      });

      executionSummary = `Budget for '${category}' successfully set to ৳${limit.toFixed(2)}/month.`;
    } else if (action.actionType === "CREATE_SAVINGS_GOAL") {
      const goalName = (action.parameters && action.parameters.goalName) || "";
      const targetAmount = Number(action.parameters && action.parameters.targetAmount);
      const targetMonths = Number(action.parameters && action.parameters.targetMonths);
      if (!goalName || isNaN(targetAmount) || targetAmount <= 0 || !targetMonths || targetMonths <= 0) {
        res.status(400).json({ error: "Invalid savings goal parameters in pending action." });
        return;
      }

      const monthlyRequired = targetAmount / targetMonths;
      const goalId = randomUUID();
      const goalDocPath = `users/${encodedDocId}/savings_goals/${goalId}`;

      writes.push({
        update: {
          name: client.docResourceName(goalDocPath),
          fields: toFirestoreFields({
            id: goalId,
            goalName,
            targetAmount,
            targetMonths,
            monthlyContribution: Number(monthlyRequired.toFixed(2)),
            currentSaved: 0.0,
            createdAt: now,
          }),
        },
      });

      executionSummary = `Savings Goal '${goalName}' established: Target ৳${targetAmount.toFixed(2)} in ${targetMonths} months (৳${monthlyRequired.toFixed(2)}/mo).`;
    } else {
      res.status(400).json({ error: `Unknown action type: ${action.actionType}` });
      return;
    }

    const auditLogId = randomUUID();
    const auditDocPath = `users/${encodedDocId}/audit_logs/${auditLogId}`;

    // Update pending action to CONFIRMED with updateTime precondition
    writes.push({
      update: {
        name: client.docResourceName(pendingActionPath),
        fields: {
          status: { stringValue: "CONFIRMED" },
          executedAt: { timestampValue: now.toISOString() },
          auditLogId: { stringValue: auditLogId },
        },
      },
      updateMask: {
        fieldPaths: ["status", "executedAt", "auditLogId"],
      },
      currentDocument: {
        updateTime: pendingDoc.updateTime,
      },
    });

    // Write audit record
    writes.push({
      update: {
        name: client.docResourceName(auditDocPath),
        fields: toFirestoreFields({
          id: auditLogId,
          uid,
          docId,
          actionId: cleanActionId,
          actionType: action.actionType,
          status: "SUCCESS",
          summary: executionSummary,
          details: action.parameters || {},
          timestamp: now,
          writtenViaAgentApi: true,
        }),
      },
    });

    // Commit atomically
    await client.commit(writes);

    res.status(200).json({
      success: true,
      summary: executionSummary,
      auditLogId,
    });
  } catch (err) {
    console.error("Action confirmation commit error:", err.message);
    const msg = (err.message || "").toLowerCase();
    if (msg.includes("precondition") || msg.includes("already") || msg.includes("conflict") || msg.includes("409")) {
      res.status(409).json({ error: "Action already processed. Replay blocked." });
      return;
    }
    if (msg.includes("permission denied") || msg.includes("403")) {
      res.status(403).json({ error: "Permission denied by security rules." });
      return;
    }
    res.status(500).json({ error: "Failed to confirm financial action. Please try again." });
  }
};
