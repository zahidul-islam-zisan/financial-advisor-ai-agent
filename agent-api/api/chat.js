/**
 * AI Assistant Chat Endpoint
 * POST /api/chat
 * Body: { message: string, history?: Array }
 * Headers: Authorization: Bearer <Firebase ID token>
 */
const { handleCors, authenticateRequest } = require("../lib/auth");
const { FirestoreRestClient } = require("../lib/db");
const { checkRateLimit } = require("../lib/ratelimit");
const { runAgent } = require("../lib/gemini");

module.exports = async function handler(req, res) {
  if (handleCors(req, res)) return;

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed. Use POST." });
    return;
  }

  // 1. Authenticate request via Firebase ID token
  const auth = await authenticateRequest(req, res);
  if (!auth) return; // 401 already sent by authenticateRequest

  const { uid, docId, idToken } = auth;

  // 2. Rate Limit Check (In-memory best-effort per instance)
  const rateCheck = checkRateLimit(uid);
  if (!rateCheck.allowed) {
    res.setHeader("Retry-After", String(rateCheck.retryAfter || 60));
    res.status(429).json({
      error: rateCheck.reason || "Rate limit exceeded. Please try again later.",
    });
    return;
  }

  // 3. Validate Request Body
  const { message, history = [] } = req.body || {};
  if (!message || typeof message !== "string" || message.trim().length === 0) {
    res.status(400).json({ error: "Invalid request: 'message' is required and cannot be empty." });
    return;
  }

  if (message.length > 1000) {
    res.status(400).json({ error: "Message exceeds maximum allowed length of 1000 characters." });
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

  try {
    const agentResult = await runAgent({
      client,
      uid,
      docId,
      message: message.trim(),
      history: Array.isArray(history) ? history : [],
    });

    res.status(200).json({
      reply: agentResult.reply,
      toolCalls: agentResult.toolCalls || [],
      pendingAction: agentResult.pendingAction || null,
      isOffline: !!agentResult.isOffline,
      offlineReason: agentResult.offlineReason || null,
    });
  } catch (err) {
    console.error("Chat handler execution error:", err.message);
    res.status(500).json({
      error: "An internal financial agent processing error occurred. Please try again.",
    });
  }
};
