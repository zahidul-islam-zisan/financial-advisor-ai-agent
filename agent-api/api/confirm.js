/**
 * 2-Step Financial Action Confirmation Endpoint
 * POST /api/confirm
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

      // Security Check 1: User ownership
      if (action.uid !== uid) {
        return { errorStatus: 403, message: "Forbidden: You do not own this pending action." };
      }

      // Security Check 2: Anti-replay protection
      if (action.status !== "PENDING") {
        return {
          errorStatus: 400,
          message: `Action already processed (${action.status}). Replay blocked.`,
        };
      }

      // Security Check 3: Expiration check
      const nowMs = Date.now();
      const expiresAtMs = action.expiresAt
        ? (action.expiresAt.toMillis ? action.expiresAt.toMillis() : new Date(action.expiresAt).getTime())
        : 0;

      if (expiresAtMs && nowMs > expiresAtMs) {
        transaction.update(actionRef, { status: "EXPIRED" });
        return { errorStatus: 410, message: "Pending action has expired. Please ask the AI to propose it again." };
      }

      const nowTimestamp = admin.firestore.Timestamp.now();
      let executionSummary = "";

      // Trusted Execution based on Action Type
      if (action.actionType === "CREATE_BUDGET") {
        const category = action.parameters.category;
        const limit = Number(action.parameters.limit);
        if (!category || isNaN(limit) || limit <= 0) {
          return { errorStatus: 400, message: "Invalid budget parameters." };
        }

        const categorySlug = category.toLowerCase().replace(/\s+/g, "_");
        const budgetRef = db.collection("users").doc(docId).collection("budgets").doc(categorySlug);

        transaction.set(
          budgetRef,
          {
            category,
            limit,
            updatedAt: nowTimestamp,
            createdAt: nowTimestamp,
          },
          { merge: true }
        );

        executionSummary = `Budget for '${category}' successfully set to ৳${limit.toFixed(2)}/month.`;
      } else if (action.actionType === "CREATE_SAVINGS_GOAL") {
        const goalName = action.parameters.goalName;
        const targetAmount = Number(action.parameters.targetAmount);
        const targetMonths = Number(action.parameters.targetMonths);
        const monthlyRequired = targetAmount / targetMonths;

        const goalRef = db.collection("users").doc(docId).collection("savings_goals").doc();

        transaction.set(goalRef, {
          id: goalRef.id,
          goalName,
          targetAmount,
          targetMonths,
          monthlyContribution: Number(monthlyRequired.toFixed(2)),
          currentSaved: 0.0,
          createdAt: nowTimestamp,
        });

        executionSummary = `Savings Goal '${goalName}' established: Target ৳${targetAmount.toFixed(2)} in ${targetMonths} months (৳${monthlyRequired.toFixed(2)}/mo).`;
      } else {
        return { errorStatus: 400, message: `Unknown action type: ${action.actionType}` };
      }

      // Append-only Server-Verified Audit Record
      const auditLogRef = db.collection("users").doc(docId).collection("audit_logs").doc();
      transaction.set(auditLogRef, {
        id: auditLogRef.id,
        uid,
        docId,
        actionId,
        actionType: action.actionType,
        status: "SUCCESS",
        summary: executionSummary,
        details: action.parameters || {},
        timestamp: nowTimestamp,
        verifiedByServer: true,
      });

      // Update Pending Action to Confirmed
      transaction.update(actionRef, {
        status: "CONFIRMED",
        executedAt: nowTimestamp,
        auditLogId: auditLogRef.id,
      });

      return {
        success: true,
        summary: executionSummary,
        auditLogId: auditLogRef.id,
      };
    });

    if (result.errorStatus) {
      res.status(result.errorStatus).json({ error: result.message });
      return;
    }

    res.status(200).json(result);
  } catch (err) {
    console.error("Action confirmation transaction error:", err.message);
    res.status(500).json({ error: "Failed to confirm financial action. Please try again." });
  }
};
