/**
 * Local Diagnostic & Verification Test Script for Gemini Agent API
 * Run via: node scripts/local_test.js
 */

const assert = require("node:assert");
const {
  runAgent,
  getModelName,
  buildConversationContents,
  TOOL_DECLARATIONS,
  setGeminiFetcher,
} = require("../lib/gemini");

async function main() {
  console.log("=================================================");
  console.log("  Pulse Expense AI Agent — Local Test Suite");
  console.log("=================================================\n");

  let passed = 0;
  let failed = 0;

  function runCheck(name, fn) {
    try {
      fn();
      console.log(`[PASS] ${name}`);
      passed++;
    } catch (err) {
      console.error(`[FAIL] ${name}:`, err.message);
      failed++;
    }
  }

  async function runAsyncCheck(name, fn) {
    try {
      await fn();
      console.log(`[PASS] ${name}`);
      passed++;
    } catch (err) {
      console.error(`[FAIL] ${name}:`, err.message);
      failed++;
    }
  }

  // 1. Model Configuration Check
  runCheck("1. Default primary model is gemini-3.5-flash-lite", () => {
    delete process.env.GEMINI_MODEL;
    const model = getModelName();
    assert.strictEqual(model, "gemini-3.5-flash-lite");
  });

  runCheck("2. Model name cleans whitespace and models/ prefix", () => {
    assert.strictEqual(getModelName("  models/gemini-3.5-flash-lite  "), "gemini-3.5-flash-lite");
    assert.strictEqual(getModelName("models/custom-model"), "custom-model");
  });

  // 2. Conversation Turns & Role Constraints
  runCheck("3. Drops leading assistant greetings so contents starts with 'user'", () => {
    const historyWithGreeting = [
      {
        text: "👋 Hi! I am Pulse AI, your personal financial assistant.",
        isUser: false,
      },
    ];
    const contents = buildConversationContents({
      history: historyWithGreeting,
      message: "How am I spending this month?",
    });

    assert.strictEqual(contents.length, 1);
    assert.strictEqual(contents[0].role, "user");
    assert.strictEqual(contents[0].parts[0].text, "How am I spending this month?");
  });

  runCheck("4. Merges consecutive same-role turns to enforce strict user/model alternation", () => {
    const consecutiveHistory = [
      { text: "User prompt 1", isUser: true },
      { text: "User prompt 2", isUser: true },
      { text: "Model reply 1", isUser: false },
    ];
    const contents = buildConversationContents({
      history: consecutiveHistory,
      message: "Latest question",
    });

    // Expect: user (parts: 2) -> model (parts: 1) -> user (parts: 1)
    assert.strictEqual(contents.length, 3);
    assert.strictEqual(contents[0].role, "user");
    assert.strictEqual(contents[0].parts.length, 2);
    assert.strictEqual(contents[1].role, "model");
    assert.strictEqual(contents[2].role, "user");
  });

  // 3. Multi-turn Tool Calling Flow with FunctionResponse
  await runAsyncCheck("5. Multi-turn function call sends functionResponse under role: 'user'", async () => {
    process.env.GEMINI_API_KEY = "mock-key";
    delete process.env.GEMINI_MODEL;

    const dummyDb = {
      listCollection: async () => [
        {
          id: "tx1",
          type: "Expense",
          amount: 500,
          category_name: "Food",
          date: "2026-10-15",
        },
      ],
      getDoc: async () => null,
      createDoc: async () => ({ id: "act_1" }),
      commit: async () => ({}),
    };

    let turnsExecuted = 0;
    let turn2Payload = null;

    setGeminiFetcher(async (url, options) => {
      turnsExecuted++;
      const body = JSON.parse(options.body);

      if (turnsExecuted === 1) {
        // Model requests tool execution
        return {
          ok: true,
          status: 200,
          json: async () => ({
            candidates: [
              {
                content: {
                  parts: [
                    {
                      functionCall: {
                        name: "get_summary",
                        args: { month: "2026-10" },
                      },
                    },
                  ],
                },
              },
            ],
          }),
        };
      }

      if (turnsExecuted === 2) {
        // Save the turn 2 payload to verify roles
        turn2Payload = body;
        return {
          ok: true,
          status: 200,
          json: async () => ({
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: "In October 2026, your total expenses were ৳500.00.",
                    },
                  ],
                },
              },
            ],
          }),
        };
      }
    });

    const result = await runAgent({
      client: dummyDb,
      uid: "user_test",
      docId: "test@example.com_user_test",
      message: "How am I spending this month?",
      history: [
        {
          text: "👋 Hi! I am Pulse AI",
          isUser: false,
        },
      ],
    });

    assert.strictEqual(result.isOffline, false);
    assert.ok(result.reply.includes("৳500.00"));
    assert.strictEqual(turnsExecuted, 2);

    // Verify turn 2 roles sent to Gemini
    const contents = turn2Payload.contents;
    for (const c of contents) {
      assert.notStrictEqual(
        c.role,
        "function",
        "Gemini API rejects role: 'function' (must be 'user')"
      );
    }
    const funcResponseTurn = contents.find(
      (c) => c.parts && c.parts[0] && c.parts[0].functionResponse
    );
    assert.ok(funcResponseTurn, "Must contain functionResponse part");
    assert.strictEqual(funcResponseTurn.role, "user", "functionResponse must be in role 'user'");
  });

  // 4. Tier 2 Proposal Creation Flow
  await runAsyncCheck("6. Tier 2 create_budget generates pendingAction and concludes cleanly", async () => {
    process.env.GEMINI_API_KEY = "mock-key";

    const dummyDb = {
      listCollection: async () => [],
      getDoc: async () => null,
      createDoc: async () => ({ id: "act_proposal_123" }),
      commit: async () => ({}),
    };

    setGeminiFetcher(async () => {
      return {
        ok: true,
        status: 200,
        json: async () => ({
          candidates: [
            {
              content: {
                parts: [
                  {
                    functionCall: {
                      name: "create_budget",
                      args: { category: "Dining & Food", limit: 3000 },
                    },
                  },
                ],
              },
            },
          ],
        }),
      };
    });

    const result = await runAgent({
      client: dummyDb,
      uid: "user_test",
      docId: "test@example.com_user_test",
      message: "Set my dining budget to 3000",
    });

    assert.strictEqual(result.isOffline, false);
    assert.ok(result.pendingAction, "pendingAction must be created");
    assert.strictEqual(result.pendingAction.actionType, "CREATE_BUDGET");
    assert.strictEqual(result.pendingAction.status, "PENDING");
    assert.ok(result.reply.includes("Dining & Food"));
  });

  // 5. 404 Recovery: gemini-3.5-flash-lite -> gemini-3.5-flash
  await runAsyncCheck("7. On 404, retries gemini-3.5-flash fallback model once and succeeds", async () => {
    process.env.GEMINI_API_KEY = "mock-key";
    delete process.env.GEMINI_MODEL;

    let calls = 0;
    const modelsCalled = [];

    setGeminiFetcher(async (url) => {
      calls++;
      modelsCalled.push(url);
      if (calls === 1) {
        return {
          ok: false,
          status: 404,
          text: async () => JSON.stringify({ error: { code: 404, status: "NOT_FOUND", message: "Model not found" } }),
        };
      }
      return {
        ok: true,
        status: 200,
        json: async () => ({
          candidates: [
            {
              content: {
                parts: [{ text: "Success via fallback model." }],
              },
            },
          ],
        }),
      };
    });

    const dummyDb = {
      listCollection: async () => [],
      getDoc: async () => null,
      createDoc: async () => ({ id: "1" }),
      commit: async () => ({}),
    };

    const result = await runAgent({
      client: dummyDb,
      uid: "u1",
      docId: "u1_doc",
      message: "Hello",
    });

    assert.strictEqual(result.isOffline, false);
    assert.ok(result.reply.includes("Success via fallback model"));
    assert.strictEqual(calls, 2);
    assert.ok(modelsCalled[0].includes("gemini-3.5-flash-lite"));
    assert.ok(modelsCalled[1].includes("gemini-3.5-flash"));
  });

  // Reset
  setGeminiFetcher(null);

  console.log("\n=================================================");
  console.log(`  Results: ${passed} Passed, ${failed} Failed`);
  console.log("=================================================");

  if (failed > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("Test runner error:", err);
  process.exit(1);
});
