/**
 * Health Check & Diagnostic Endpoint
 * GET /api/health
 * Optional: GET /api/health?checkGemini=true
 * Optional: GET /api/health?checkTools=true
 * Optional: GET /api/health?checkAgentLoop=true  (full multi-turn loop test)
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
  if (urlObj.searchParams.get("checkListModels") === "true") {
    if (!hasApiKey) {
      res.status(200).json({ ok: false, error: "GEMINI_API_KEY missing" });
      return;
    }
    try {
      const gRes = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models`,
        {
          method: "GET",
          headers: {
            "x-goog-api-key": key,
          },
        }
      );
      const data = await gRes.json();
      const modelNames = (data.models || []).map((m) => m.name.replace("models/", ""));
      res.status(200).json({
        ok: gRes.ok,
        status: gRes.status,
        modelsCount: modelNames.length,
        models: modelNames,
      });
      return;
    } catch (err) {
      res.status(200).json({ ok: false, error: err.message });
      return;
    }
  }

  // Optional in-cloud Gemini test WITH tool declarations
  if (urlObj.searchParams.get("checkTools") === "true") {
    if (!hasApiKey) {
      res.status(200).json({ ok: false, error: "GEMINI_API_KEY missing" });
      return;
    }
    try {
      const chosenModel = (urlObj.searchParams.get("model") || model).trim();
      const cleanModel = chosenModel.startsWith("models/") ? chosenModel.slice(7) : chosenModel;
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
        version: "1.0.7",
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

  // Full multi-turn agent loop diagnostic (simulates /api/chat without auth)
  if (urlObj.searchParams.get("checkAgentLoop") === "true") {
    if (!hasApiKey) {
      res.status(200).json({ ok: false, error: "GEMINI_API_KEY missing" });
      return;
    }
    try {
      const chosenModel = (urlObj.searchParams.get("model") || model).trim();
      const cleanModel = chosenModel.startsWith("models/") ? chosenModel.slice(7) : chosenModel;
      const diagnosticLog = [];

      // Step 1: Send initial user message with tools
      diagnosticLog.push({ step: 1, action: "Initial Gemini call with tools" });
      const contents = [
        { role: "user", parts: [{ text: "How am I spending this month?" }] },
      ];

      const step1Res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${cleanModel}:generateContent`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": key,
          },
          body: JSON.stringify({
            contents,
            systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
            tools: TOOL_DECLARATIONS,
            generationConfig: { temperature: 0.2, maxOutputTokens: 1024 },
          }),
        }
      );

      const step1Status = step1Res.status;
      const step1Body = await step1Res.text();
      let step1Json;
      try { step1Json = JSON.parse(step1Body); } catch (_) { step1Json = step1Body; }

      diagnosticLog.push({ step: 1, status: step1Status, ok: step1Res.ok });

      if (!step1Res.ok) {
        res.status(200).json({
          ok: false, version: "1.0.7", testModel: cleanModel,
          failedAt: "step1_initial_call", status: step1Status,
          error: typeof step1Json === "object" ? step1Json : step1Body.slice(0, 500),
          diagnosticLog,
        });
        return;
      }

      // Check if Gemini returned a functionCall
      const candidate = step1Json.candidates?.[0];
      const parts = candidate?.content?.parts || [];
      const functionCall = parts.find(p => p.functionCall)?.functionCall;

      if (!functionCall) {
        // Gemini returned text directly, no tool loop needed
        const textReply = parts.find(p => p.text)?.text || "";
        res.status(200).json({
          ok: true, version: "1.0.7", testModel: cleanModel,
          result: "Gemini returned text without tool call",
          replyPreview: textReply.slice(0, 200),
          diagnosticLog,
        });
        return;
      }

      diagnosticLog.push({
        step: 2,
        action: "Gemini requested tool call",
        toolName: functionCall.name,
        toolArgs: functionCall.args,
      });

      // Step 2: Simulate tool execution and send functionResponse back
      const mockToolResult = {
        month: "2026-10",
        currency: "৳",
        totalIncome: 50000,
        totalExpense: 28500,
        netSavings: 21500,
        savingsRate: 43.0,
        categoryBreakdown: { "Dining & Food": 5200, "Transportation": 3800, "Shopping": 2500 },
        transactionCount: 22,
      };

      // Build the multi-turn contents EXACTLY like runAgent does
      contents.push({
        role: "model",
        parts: [{ functionCall }],
      });

      // Build functionResponse with id matching (required for Gemini 3.x+)
      const functionResponsePart = {
        functionResponse: {
          name: functionCall.name,
          response: {
            name: functionCall.name,
            content: mockToolResult,
          },
        },
      };
      // If the model's functionCall included an id, echo it back
      if (functionCall.id) {
        functionResponsePart.functionResponse.id = functionCall.id;
      }
      
      contents.push({
        role: "user",
        parts: [functionResponsePart],
      });

      diagnosticLog.push({
        step: 3,
        action: "Sending functionResponse back to Gemini",
        contentsLength: contents.length,
        contentsRoles: contents.map(c => c.role),
      });

      const step2Res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${cleanModel}:generateContent`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": key,
          },
          body: JSON.stringify({
            contents,
            systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
            tools: TOOL_DECLARATIONS,
            generationConfig: { temperature: 0.2, maxOutputTokens: 1024 },
          }),
        }
      );

      const step2Status = step2Res.status;
      const step2Body = await step2Res.text();
      let step2Json;
      try { step2Json = JSON.parse(step2Body); } catch (_) { step2Json = step2Body; }

      diagnosticLog.push({ step: 3, status: step2Status, ok: step2Res.ok });

      if (!step2Res.ok) {
        res.status(200).json({
          ok: false, version: "1.0.7", testModel: cleanModel,
          failedAt: "step3_functionResponse_call",
          status: step2Status,
          error: typeof step2Json === "object" ? step2Json : step2Body.slice(0, 500),
          sentContents: contents, // Show exactly what was sent
          diagnosticLog,
        });
        return;
      }

      // Check step 2 response
      const candidate2 = step2Json.candidates?.[0];
      const parts2 = candidate2?.content?.parts || [];
      const textReply = parts2.find(p => p.text)?.text || "";
      const anotherToolCall = parts2.find(p => p.functionCall);

      diagnosticLog.push({
        step: 4,
        action: "Final response from Gemini",
        hasText: !!textReply,
        hasAnotherToolCall: !!anotherToolCall,
        replyPreview: textReply.slice(0, 200),
      });

      res.status(200).json({
        ok: true, version: "1.0.7", testModel: cleanModel,
        result: "Full agent loop completed successfully",
        replyPreview: textReply.slice(0, 300),
        toolCallExecuted: functionCall.name,
        anotherToolRequested: anotherToolCall?.functionCall?.name || null,
        diagnosticLog,
      });
    } catch (err) {
      res.status(200).json({ ok: false, error: err.message, stack: err.stack?.slice(0, 300) });
    }
    return;
  }

  // Basic check
  if (urlObj.searchParams.get("checkGemini") === "true") {
    if (!hasApiKey) {
      res.status(200).json({ ok: false, error: "GEMINI_API_KEY missing", version: "1.0.7" });
      return;
    }

    try {
      const chosenModel = (urlObj.searchParams.get("model") || model).trim();
      const cleanModel = chosenModel.startsWith("models/") ? chosenModel.slice(7) : chosenModel;
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
        version: "1.0.7",
        testModel: cleanModel,
        geminiHttpStatus: status,
        geminiSuccess: gRes.ok,
        geminiResponse: gRes.ok ? "Gemini API connected successfully!" : parsed,
      });
      return;
    } catch (err) {
      res.status(200).json({ ok: false, version: "1.0.7", geminiError: err.message });
      return;
    }
  }

  res.status(200).json({
    ok: true,
    version: "1.0.7",
    timestamp: new Date().toISOString(),
    configuredModel: model,
    hasApiKey,
    hasProjectId,
  });
};
