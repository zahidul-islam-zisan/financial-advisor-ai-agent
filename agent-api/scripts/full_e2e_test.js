#!/usr/bin/env node
/**
 * Full End-to-End Human Simulation Test
 * Tests every endpoint against the LIVE Vercel deployment
 * and also tests internal Gemini integration locally.
 *
 * Usage: node agent-api/scripts/full_e2e_test.js
 *
 * Requires GEMINI_API_KEY in .env.local or environment.
 */

const BASE_URL = "https://financial-advisor-ai-agent-api.vercel.app";

let passed = 0;
let failed = 0;
const failures = [];

function assert(condition, testName, detail = "") {
  if (condition) {
    passed++;
    console.log(`  ✅ ${testName}`);
  } else {
    failed++;
    console.log(`  ❌ ${testName}${detail ? ": " + detail : ""}`);
    failures.push(`${testName}: ${detail}`);
  }
}

async function fetchJson(url, options = {}) {
  const res = await fetch(url, options);
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (_) {}
  return { status: res.status, ok: res.ok, text, json, headers: res.headers };
}

// =========================================================================
// SECTION 1: Health Endpoint Tests
// =========================================================================
async function testHealthEndpoint() {
  console.log("\n🔵 SECTION 1: GET /api/health");

  // 1a. Basic health check
  const h1 = await fetchJson(`${BASE_URL}/api/health`);
  assert(h1.status === 200, "Health returns 200");
  assert(h1.json && h1.json.ok === true, "Health ok=true");
  assert(h1.json && h1.json.status === "healthy", "Health status='healthy'");

  // 1b. OPTIONS
  const h4 = await fetch(`${BASE_URL}/api/health`, { method: "OPTIONS" });
  assert(h4.status === 204, "Health OPTIONS returns 204");

  // 1c. POST should be 405
  const h5 = await fetchJson(`${BASE_URL}/api/health`, { method: "POST" });
  assert(h5.status === 405, "Health POST returns 405");
}

// =========================================================================
// SECTION 2: Chat Endpoint (Auth + Request Validation)
// =========================================================================
async function testChatEndpoint() {
  console.log("\n🔵 SECTION 2: POST /api/chat (Auth & Validation)");

  // 2a. OPTIONS (CORS preflight)
  const c0 = await fetch(`${BASE_URL}/api/chat`, { method: "OPTIONS" });
  assert(c0.status === 204, "Chat OPTIONS returns 204");

  // 2b. GET should be 405
  const c1 = await fetchJson(`${BASE_URL}/api/chat`, { method: "GET" });
  assert(c1.status === 405, "Chat GET returns 405");

  // 2c. POST without auth header -> 401
  const c2 = await fetchJson(`${BASE_URL}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message: "hello" }),
  });
  assert(c2.status === 401, "Chat POST without auth returns 401",
    `Got ${c2.status}: ${c2.text.slice(0, 200)}`);

  // 2d. POST with invalid bearer token -> 401
  const c3 = await fetchJson(`${BASE_URL}/api/chat`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer invalid.token.here",
    },
    body: JSON.stringify({ message: "hello" }),
  });
  assert(c3.status === 401, "Chat POST with invalid token returns 401",
    `Got ${c3.status}: ${c3.text.slice(0, 200)}`);

  // 2e. POST with valid token but empty message -> 400 (simulate with fake valid-looking token)
  // Can't test this without real token, so we just verify auth gate works
  assert(c2.json?.error?.toLowerCase().includes("unauthorized") || c2.json?.error?.toLowerCase().includes("bearer"),
    "401 error message mentions unauthorized/bearer");
}

// =========================================================================
// SECTION 3: Confirm Endpoint (Auth + Validation)
// =========================================================================
async function testConfirmEndpoint() {
  console.log("\n🔵 SECTION 3: POST /api/confirm (Auth & Validation)");

  // 3a. OPTIONS
  const co = await fetch(`${BASE_URL}/api/confirm`, { method: "OPTIONS" });
  assert(co.status === 204, "Confirm OPTIONS returns 204");

  // 3b. GET -> 405
  const c1 = await fetchJson(`${BASE_URL}/api/confirm`, { method: "GET" });
  assert(c1.status === 405, "Confirm GET returns 405");

  // 3c. POST without auth -> 401
  const c2 = await fetchJson(`${BASE_URL}/api/confirm`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ actionId: "test-123" }),
  });
  assert(c2.status === 401, "Confirm POST without auth returns 401",
    `Got ${c2.status}`);
}

// =========================================================================
// SECTION 4: Cancel Endpoint (Auth + Validation)
// =========================================================================
async function testCancelEndpoint() {
  console.log("\n🔵 SECTION 4: POST /api/cancel (Auth & Validation)");

  const co = await fetch(`${BASE_URL}/api/cancel`, { method: "OPTIONS" });
  assert(co.status === 204, "Cancel OPTIONS returns 204");

  const c1 = await fetchJson(`${BASE_URL}/api/cancel`, { method: "GET" });
  assert(c1.status === 405, "Cancel GET returns 405");

  const c2 = await fetchJson(`${BASE_URL}/api/cancel`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ actionId: "test-456" }),
  });
  assert(c2.status === 401, "Cancel POST without auth returns 401",
    `Got ${c2.status}`);
}

// =========================================================================
// SECTION 5: Gemini Integration - Direct API test with tool calls
// =========================================================================
async function testGeminiDirect() {
  console.log("\n🔵 SECTION 5: Direct Gemini API Tests (Model & Schema Validation)");

  // Load key from env or .env.local
  let apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    try {
      const fs = require("fs");
      const path = require("path");
      const envFile = fs.readFileSync(path.join(__dirname, "..", ".env.local"), "utf8");
      const match = envFile.match(/^GEMINI_API_KEY=(.+)$/m);
      if (match) apiKey = match[1].trim();
    } catch (_) {}
  }

  if (!apiKey || apiKey === "YOUR_GEMINI_API_KEY_HERE") {
    console.log("  ⚠️ SKIPPED: No GEMINI_API_KEY available for direct Gemini tests");
    return;
  }

  const { TOOL_DECLARATIONS, SYSTEM_INSTRUCTION, buildConversationContents } = require("../lib/gemini");

  // 5a. Test model availability - gemini-3.5-flash-lite
  const models = ["gemini-3.5-flash-lite", "gemini-3.5-flash"];
  for (const model of models) {
    const res = await fetchJson(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: "Say 'OK'" }] }],
        }),
      }
    );
    assert(res.status === 200, `Model ${model} is available (HTTP ${res.status})`,
      res.status !== 200 ? `Error: ${res.text.slice(0, 300)}` : "");
  }

  // 5b. Test tool declarations with simple user message
  const toolTestRes = await fetchJson(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: "Show my spending summary" }] }],
        systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
        tools: TOOL_DECLARATIONS,
        generationConfig: { temperature: 0.2, maxOutputTokens: 1024 },
      }),
    }
  );
  assert(toolTestRes.status === 200, "Tool declarations accepted by Gemini (HTTP 200)",
    toolTestRes.status !== 200 ? `Error: ${toolTestRes.text.slice(0, 400)}` : "");

  // 5c. Test multi-turn with function response (THE CRITICAL PATH)
  // This simulates what happens when Gemini calls get_summary and we send back the result
  const multiTurnContents = [
    { role: "user", parts: [{ text: "Show my spending summary" }] },
    { role: "model", parts: [{ functionCall: { name: "get_summary", args: {} } }] },
    {
      role: "user",
      parts: [
        {
          functionResponse: {
            name: "get_summary",
            response: {
              name: "get_summary",
              content: {
                month: "2026-10",
                currency: "৳",
                totalIncome: 50000,
                totalExpense: 30000,
                netSavings: 20000,
                savingsRate: 40,
                categoryBreakdown: { "Dining & Food": 5000, "Transportation": 3000 },
                transactionCount: 15,
              },
            },
          },
        },
      ],
    },
  ];

  const multiTurnRes = await fetchJson(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        contents: multiTurnContents,
        systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
        tools: TOOL_DECLARATIONS,
        generationConfig: { temperature: 0.2, maxOutputTokens: 1024 },
      }),
    }
  );
  assert(multiTurnRes.status === 200, "Multi-turn with functionResponse accepted (HTTP 200)",
    multiTurnRes.status !== 200 ? `CRITICAL: ${multiTurnRes.text.slice(0, 500)}` : "");

  if (multiTurnRes.status === 200 && multiTurnRes.json?.candidates?.[0]) {
    const parts = multiTurnRes.json.candidates[0].content?.parts || [];
    const hasText = parts.some(p => p.text);
    assert(hasText, "Gemini returned text response after functionResponse");
    if (hasText) {
      const text = parts.find(p => p.text)?.text || "";
      console.log(`    Response preview: "${text.slice(0, 150)}..."`);
    }
  }

  // 5d. Test buildConversationContents with history like Flutter sends
  const flutterHistory = [
    { text: "👋 Hi! I am Pulse AI, your intelligent financial advisor. How can I help?", isUser: false },
    { text: "How am I spending?", isUser: true },
    { text: "Here is your spending summary...", isUser: false },
    { text: "Show budget status", isUser: true },
  ];
  const builtContents = buildConversationContents({
    history: flutterHistory,
    message: "Tell me more",
  });

  assert(builtContents[0].role === "user", "buildConversationContents strips leading model turn",
    `First role: ${builtContents[0].role}`);
  
  // Verify alternation
  let alternationOk = true;
  for (let i = 1; i < builtContents.length; i++) {
    if (builtContents[i].role === builtContents[i - 1].role) {
      alternationOk = false;
      break;
    }
  }
  assert(alternationOk, "buildConversationContents ensures strict role alternation");

  // Now test these built contents with Gemini API directly
  const builtRes = await fetchJson(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        contents: builtContents,
        systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
        tools: TOOL_DECLARATIONS,
        generationConfig: { temperature: 0.2, maxOutputTokens: 1024 },
      }),
    }
  );
  assert(builtRes.status === 200, "Flutter-style history processed by Gemini successfully",
    builtRes.status !== 200 ? `ERROR: ${builtRes.text.slice(0, 500)}` : "");

  // 5e. Test edge case: empty history (first message)
  const firstMsgContents = buildConversationContents({
    history: [],
    message: "Hello, how are you?",
  });
  assert(firstMsgContents.length === 1, "Empty history produces single user turn");
  assert(firstMsgContents[0].role === "user", "Single turn is user role");

  const firstMsgRes = await fetchJson(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        contents: firstMsgContents,
        systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
        tools: TOOL_DECLARATIONS,
        generationConfig: { temperature: 0.2, maxOutputTokens: 1024 },
      }),
    }
  );
  assert(firstMsgRes.status === 200, "First message (empty history) accepted by Gemini");

  // 5f. Test edge case: history with only model greetings (should strip all, leave just new user message)
  const greetOnlyHistory = [
    { text: "👋 Hi! I am Pulse AI, your intelligent financial advisor.", isUser: false },
  ];
  const greetContents = buildConversationContents({
    history: greetOnlyHistory,
    message: "What are my bills?",
  });
  assert(greetContents[0].role === "user", "Greeting-only history strips model turn correctly");
}

// =========================================================================
// SECTION 6: Local runAgent simulation (using mock Firestore)
// =========================================================================
async function testRunAgentLocal() {
  console.log("\n🔵 SECTION 6: Local runAgent() with real Gemini + mock Firestore");

  let apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    try {
      const fs = require("fs");
      const path = require("path");
      const envFile = fs.readFileSync(path.join(__dirname, "..", ".env.local"), "utf8");
      const match = envFile.match(/^GEMINI_API_KEY=(.+)$/m);
      if (match) apiKey = match[1].trim();
    } catch (_) {}
  }

  if (!apiKey || apiKey === "YOUR_GEMINI_API_KEY_HERE") {
    console.log("  ⚠️ SKIPPED: No GEMINI_API_KEY available");
    return;
  }

  // Set env for runAgent
  process.env.GEMINI_API_KEY = apiKey;
  process.env.GEMINI_MODEL = "gemini-3.5-flash-lite";
  process.env.FIREBASE_PROJECT_ID = "pulse-expense-3156f";

  const { runAgent, setGeminiFetcher } = require("../lib/gemini");

  // Reset to real fetch
  setGeminiFetcher(null);

  // Mock Firestore client that returns sample data
  const mockClient = {
    listCollection: async (path) => {
      if (path.includes("income_expenses")) {
        return [
          { id: "t1", amount: 1200, isIncome: false, category_name: "Dining & Food", date: "2026-10-05", description: "Lunch" },
          { id: "t2", amount: 800, isIncome: false, category_name: "Transportation", date: "2026-10-10", description: "Uber" },
          { id: "t3", amount: 50000, isIncome: true, category_name: "Salary", date: "2026-10-01", description: "Monthly salary" },
        ];
      }
      if (path.includes("budgets")) {
        return [
          { id: "dining_&_food", category: "Dining & Food", limit: 5000 },
        ];
      }
      return [];
    },
    createDoc: async () => ({ id: "mock-pending-action-id" }),
    getDoc: async () => null,
  };

  // 6a. Simple first message with real Gemini
  try {
    const result = await runAgent({
      client: mockClient,
      uid: "test-uid-123",
      docId: "test@example.com_test-uid-123",
      message: "How am I doing this month?",
      history: [],
    });

    assert(typeof result.reply === "string" && result.reply.length > 0,
      "runAgent returns non-empty reply");
    assert(typeof result.isOffline === "boolean",
      "runAgent returns isOffline boolean");
    
    if (result.isOffline) {
      console.log(`    ⚠️ runAgent fell back to offline! offlineReason: ${result.offlineReason}`);
      assert(false, "runAgent should NOT fall back to offline with valid API key",
        `offlineReason: ${result.offlineReason}`);
    } else {
      assert(true, "runAgent returned ONLINE response (isOffline=false) ✨");
      console.log(`    Reply preview: "${result.reply.slice(0, 150)}..."`);
      console.log(`    Tool calls: ${JSON.stringify(result.toolCalls.map(t => t.name))}`);
    }
  } catch (err) {
    assert(false, "runAgent execution", `Threw: ${err.message}`);
  }

  // 6b. With conversation history (like Flutter app sends)
  try {
    const result = await runAgent({
      client: mockClient,
      uid: "test-uid-123",
      docId: "test@example.com_test-uid-123",
      message: "Show my budget status",
      history: [
        { text: "👋 Hi! I am Pulse AI, your intelligent financial advisor.", isUser: false },
        { text: "How am I doing this month?", isUser: true },
        { text: "Here is your spending overview...", isUser: false },
      ],
    });

    assert(typeof result.reply === "string" && result.reply.length > 0,
      "runAgent with history returns reply");
    
    if (result.isOffline) {
      assert(false, "runAgent with history should be online",
        `offlineReason: ${result.offlineReason}`);
    } else {
      assert(true, "runAgent with history returned ONLINE ✨");
    }
  } catch (err) {
    assert(false, "runAgent with history", `Threw: ${err.message}`);
  }
}

// =========================================================================
// SECTION 7: Live Vercel /api/chat with tool call simulation
// =========================================================================
async function testVercelChatTools() {
  console.log("\n🔵 SECTION 7: Vercel /api/chat full round-trip diagnostic");
  console.log("  (Requires real Firebase ID token - this tests only the tool check endpoint)");

  // Use checkTools to verify the LIVE deployment processes tools correctly
  const res = await fetchJson(`${BASE_URL}/api/health?checkTools=true`);
  
  if (res.json?.success) {
    const candidate = res.json.details?.candidates?.[0];
    if (candidate?.content?.parts) {
      const parts = candidate.content.parts;
      const functionCalls = parts.filter(p => p.functionCall);
      const textParts = parts.filter(p => p.text);
      
      assert(functionCalls.length > 0 || textParts.length > 0,
        "Live Vercel Gemini with tools returns function calls or text");

      if (functionCalls.length > 0) {
        console.log(`    Tool calls: ${functionCalls.map(p => p.functionCall.name).join(", ")}`);
      }
      if (textParts.length > 0) {
        console.log(`    Text: "${textParts[0].text.slice(0, 100)}..."`);
      }
    }
  } else {
    assert(false, "Live Vercel tool check", `Failed: ${JSON.stringify(res.json).slice(0, 300)}`);
  }
}

// =========================================================================
// SECTION 8: URL Construction Validation (Flutter-side simulation)
// =========================================================================
async function testUrlConstruction() {
  console.log("\n🔵 SECTION 8: URL Construction Validation");

  const baseUrl = "https://financial-advisor-ai-agent-api.vercel.app";
  const endpoints = ["/api/chat", "/api/confirm", "/api/cancel", "/api/health"];

  for (const ep of endpoints) {
    const cleanBaseUrl = baseUrl.endsWith("/") ? baseUrl.slice(0, -1) : baseUrl;
    const cleanEndpoint = ep.startsWith("/") ? ep : `/${ep}`;
    const url = `${cleanBaseUrl}${cleanEndpoint}`;
    assert(!url.includes("//api"), `No double slash in ${ep} URL: ${url}`);
    assert(url.startsWith("https://"), `HTTPS prefix for ${ep}`);
  }

  // Test with trailing slash base
  const trailingSlashBase = "https://financial-advisor-ai-agent-api.vercel.app/";
  const cleanBase = trailingSlashBase.endsWith("/") ? trailingSlashBase.slice(0, -1) : trailingSlashBase;
  const testUrl = `${cleanBase}/api/chat`;
  assert(!testUrl.includes("//api"), "Trailing slash base URL handled correctly");
}

// =========================================================================
// MAIN
// =========================================================================
async function main() {
  console.log("╔══════════════════════════════════════════════════════════════╗");
  console.log("║  PULSE AI AGENT - FULL END-TO-END HUMAN SIMULATION TEST    ║");
  console.log("║  Testing: Health, Chat, Confirm, Cancel, Gemini, Tools     ║");
  console.log(`║  Target: ${BASE_URL}  ║`);
  console.log("╚══════════════════════════════════════════════════════════════╝");

  await testHealthEndpoint();
  await testChatEndpoint();
  await testConfirmEndpoint();
  await testCancelEndpoint();
  await testGeminiDirect();
  await testRunAgentLocal();
  await testUrlConstruction();

  console.log("\n" + "═".repeat(60));
  console.log(`RESULTS: ${passed} passed, ${failed} failed out of ${passed + failed} tests`);
  if (failures.length > 0) {
    console.log("\nFAILURES:");
    for (const f of failures) {
      console.log(`  ❌ ${f}`);
    }
  }
  console.log("═".repeat(60));

  process.exit(failed > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(2);
});
