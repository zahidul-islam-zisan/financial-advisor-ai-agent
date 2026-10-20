/**
 * Health Check & Diagnostic Endpoint
 * GET /api/health
 * Optional: GET /api/health?checkGemini=true
 * Optional: GET /api/health?checkTools=true
 */
const { TOOL_DECLARATIONS, SYSTEM_INSTRUCTION } = require("../lib/gemini");

module.exports = async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).end();
    return;
  }

  if (req.method !== "GET") {
    res.status(405).json({ error: "Method not allowed. Use GET." });
    return;
  }

  const key = (process.env.GEMINI_API_KEY || "").trim();
  const hasApiKey = Boolean(key && key !== "YOUR_GEMINI_API_KEY_HERE");
  const model = (process.env.GEMINI_MODEL || "gemini-3.5-flash-lite").trim();
  const hasProjectId = Boolean(process.env.FIREBASE_PROJECT_ID);

  const urlObj = new URL(req.url, `https://${req.headers.host || "localhost"}`);
  
  // Optional in-cloud Gemini test WITH tool declarations
  if (urlObj.searchParams.get("checkTools") === "true") {
    if (!hasApiKey) {
      res.status(200).json({ ok: false, error: "GEMINI_API_KEY missing" });
      return;
    }
    try {
      const cleanModel = model.startsWith("models/") ? model.slice(7) : model;
      const gRes = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${cleanModel}:generateContent`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": key,
          },
          body: JSON.stringify({
            contents: [
              {
                role: "user",
                parts: [{ text: "How am I spending this month?" }],
              },
            ],
            systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
            tools: TOOL_DECLARATIONS,
            generationConfig: {
              temperature: 0.2,
              maxOutputTokens: 1024,
            },
          }),
        }
      );
      const status = gRes.status;
      const body = await gRes.text();
      let parsed = null;
      try {
        parsed = JSON.parse(body);
      } catch (_) {
        parsed = body;
      }
      res.status(200).json({
        ok: true,
        version: "1.0.6",
        testModel: cleanModel,
        status,
        success: gRes.ok,
        details: parsed,
      });
      return;
    } catch (err) {
      res.status(200).json({ ok: false, error: err.message });
      return;
    }
  }

  // Basic check
  if (urlObj.searchParams.get("checkGemini") === "true") {
    if (!hasApiKey) {
      res.status(200).json({ ok: false, error: "GEMINI_API_KEY missing", version: "1.0.6" });
      return;
    }

    try {
      const cleanModel = model.startsWith("models/") ? model.slice(7) : model;
      const gRes = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${cleanModel}:generateContent`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": key,
          },
          body: JSON.stringify({
            contents: [
              {
                role: "user",
                parts: [{ text: "Hello from Pulse Expense health check. Reply 'OK'." }],
              },
            ],
          }),
        }
      );

      const status = gRes.status;
      const body = await gRes.text();
      let parsed = null;
      try {
        parsed = JSON.parse(body);
      } catch (_) {
        parsed = body;
      }

      res.status(200).json({
        ok: true,
        version: "1.0.6",
        testModel: cleanModel,
        geminiHttpStatus: status,
        geminiSuccess: gRes.ok,
        geminiResponse: gRes.ok ? "Gemini API connected successfully!" : parsed,
      });
      return;
    } catch (err) {
      res.status(200).json({ ok: false, version: "1.0.6", geminiError: err.message });
      return;
    }
  }

  res.status(200).json({
    ok: true,
    version: "1.0.6",
    timestamp: new Date().toISOString(),
    configuredModel: model,
    hasApiKey,
    hasProjectId,
  });
};
