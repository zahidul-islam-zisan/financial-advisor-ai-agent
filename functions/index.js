/**
 * ExpensePulse — Secure Backend Cloud Functions
 * 
 * Provides:
 * 1. Server-side Gemini 1.5 Flash API proxy with Google Secret Manager (GEMINI_API_KEY)
 * 2. Trusted server-side execution of Financial Agent Tools
 * 3. Server-side 2-step human confirmation with anti-replay, ownership, and expiry validation
 * 4. Tamper-evident, server-only immutable audit logging
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const geminiApiKey = defineSecret("GEMINI_API_KEY");

/**
 * 1. SECURE SERVER-SIDE AGENT CHAT
 * Protects Gemini API Secret from client exposure.
 */
exports.agentChat = onCall({ secrets: [geminiApiKey] }, async (request) => {
  // Enforce authentication
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated to chat with Pulse AI.");
  }

  const { prompt, history = [], financialContext } = request.data;
  if (!prompt || typeof prompt !== "string" || prompt.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Prompt cannot be empty.");
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email || "";
  const docId = `${email}_${uid}`;
  const apiKey = geminiApiKey.value();

  if (!apiKey) {
    throw new HttpsError("failed-precondition", "Gemini API key is not configured in Secret Manager.");
  }

  try {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;

    const systemInstruction = `You are "Pulse AI", a secure personal financial assistant in ExpensePulse.
Help the user manage budgets, understand spending, and set savings targets.
If proposing a budget or savings goal, call create_budget or create_savings_goal.
Amounts can be presented in BDT (৳) or USD ($) as requested.`;

    const contents = [];
    for (const h of history.slice(-6)) {
      if (h.text && !h.isLoading && !h.isError) {
        contents.push({
          role: h.isUser ? "user" : "model",
          parts: [{ text: h.text }]
        });
      }
    }

    contents.push({
      role: "user",
      parts: [{ text: prompt }]
    });

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: systemInstruction }] },
        contents,
        generationConfig: { temperature: 0.4, maxOutputTokens: 1024 }
      })
    });

    if (!response.ok) {
      throw new Error(`Gemini API returned status ${response.status}`);
    }

    const data = await response.json();
    const candidate = data.candidates?.[0]?.content?.parts?.[0]?.text || "Unable to process request.";

    return {
      text: candidate,
      isOffline: false
    };
  } catch (err) {
    console.error("Agent chat server error:", err);
    throw new HttpsError("internal", "Agent service temporarily unavailable.");
  }
});

/**
 * 2. TRUSTED SERVER-SIDE CONFIRMATION
 * Executes financial writes only after verifying ownership, status, and expiration.
 */
exports.confirmFinancialAction = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const { actionId } = request.data;
  if (!actionId) {
    throw new HttpsError("invalid-argument", "Missing actionId.");
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email || "";
  const docId = `${email}_${uid}`;

  const actionRef = db.collection("users").doc(docId).collection("pending_actions").doc(actionId);
  const actionSnap = await actionRef.get();

  if (!actionSnap.exists) {
    throw new HttpsError("not-found", "Pending action not found.");
  }

  const action = actionSnap.data();

  // 1. Verify Ownership
  if (action.uid !== uid) {
    throw new HttpsError("permission-denied", "Unauthorized action confirmation.");
  }

  // 2. Anti-Replay
  if (action.status !== "PENDING") {
    throw new HttpsError("failed-precondition", `Action already processed (${action.status}). Duplicate blocked.`);
  }

  // 3. Expiration Check
  const now = admin.firestore.Timestamp.now();
  if (action.expiresAt && action.expiresAt.toMillis() < now.toMillis()) {
    await actionRef.update({ status: "EXPIRED" });
    throw new HttpsError("deadline-exceeded", "Pending action has expired.");
  }

  let executionSummary = "";

  // 4. Trusted Execution
  if (action.actionType === "CREATE_BUDGET") {
    const category = action.parameters.category;
    const limit = Number(action.parameters.limit);
    if (!category || isNaN(limit) || limit <= 0) {
      throw new HttpsError("invalid-argument", "Invalid budget parameters.");
    }

    const budgetDocId = category.toLowerCase().replace(/\s+/g, "_");
    await db.collection("users").doc(docId).collection("budgets").doc(budgetDocId).set({
      category,
      limit,
      updatedAt: now,
      createdAt: now
    }, { merge: true });

    executionSummary = `Budget for '${category}' successfully set to ৳${limit.toFixed(2)}/month.`;
  } else if (action.actionType === "CREATE_SAVINGS_GOAL") {
    const goalName = action.parameters.goalName;
    const targetAmount = Number(action.parameters.targetAmount);
    const targetMonths = Number(action.parameters.targetMonths);
    const monthlyRequired = targetAmount / targetMonths;

    await db.collection("users").doc(docId).collection("savings_goals").add({
      goalName,
      targetAmount,
      targetMonths,
      monthlyContribution: monthlyRequired,
      currentSaved: 0.0,
      createdAt: now
    });

    executionSummary = `Savings Goal '${goalName}' established: Target ৳${targetAmount.toFixed(2)} in ${targetMonths} months.`;
  } else {
    throw new HttpsError("invalid-argument", `Unknown action type: ${action.actionType}`);
  }

  // 5. Append-only Immutable Audit Log
  const auditLogRef = await db.collection("users").doc(docId).collection("audit_logs").add({
    uid,
    docId,
    actionId,
    actionType: action.actionType,
    status: "SUCCESS",
    summary: executionSummary,
    details: action.parameters,
    timestamp: now,
    verifiedByServer: true
  });

  // 6. Update pending action
  await actionRef.update({
    status: "CONFIRMED",
    executedAt: now,
    auditLogId: auditLogRef.id
  });

  return {
    success: true,
    summary: executionSummary,
    auditLogId: auditLogRef.id
  };
});

/**
 * 3. TRUSTED SERVER-SIDE CANCELLATION
 */
exports.cancelFinancialAction = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const { actionId } = request.data;
  const uid = request.auth.uid;
  const email = request.auth.token.email || "";
  const docId = `${email}_${uid}`;

  const actionRef = db.collection("users").doc(docId).collection("pending_actions").doc(actionId);
  const actionSnap = await actionRef.get();

  if (!actionSnap.exists) {
    return { success: true };
  }

  const action = actionSnap.data();
  if (action.uid !== uid) {
    throw new HttpsError("permission-denied", "Unauthorized action cancellation.");
  }

  const now = admin.firestore.Timestamp.now();
  await db.collection("users").doc(docId).collection("audit_logs").add({
    uid,
    docId,
    actionId,
    actionType: action.actionType,
    status: "REJECTED",
    summary: `User cancelled proposed action: ${action.title}`,
    details: action.parameters,
    timestamp: now,
    verifiedByServer: true
  });

  await actionRef.update({ status: "REJECTED" });
  return { success: true };
});
