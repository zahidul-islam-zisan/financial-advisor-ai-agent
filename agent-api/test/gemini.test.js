const { describe, it, beforeEach, afterEach } = require("node:test");
const assert = require("node:assert");
const {
  runAgent,
  mapStatusToOfflineReason,
  TOOL_DECLARATIONS,
  setGeminiFetcher,
} = require("../lib/gemini");

describe("Gemini Agent API, Diagnostics & Tool Schema Tests", () => {
  const originalEnv = process.env.GEMINI_API_KEY;
  let loggedErrors = [];
  const originalConsoleError = console.error;

  beforeEach(() => {
    loggedErrors = [];
    console.error = (...args) => {
      loggedErrors.push(args.join(" "));
    };
  });

  afterEach(() => {
    console.error = originalConsoleError;
    process.env.GEMINI_API_KEY = originalEnv;
    setGeminiFetcher(null);
  });

  const dummyClient = {
    listCollection: async () => [],
    getDoc: async () => null,
    createDoc: async () => ({ id: "mock_id" }),
    commit: async () => ({}),
  };

  it("1. Missing or placeholder GEMINI_API_KEY returns offlineReason: 'missing_key' and logs 'GEMINI_API_KEY missing'", async () => {
    delete process.env.GEMINI_API_KEY;

    const result = await runAgent({
      client: dummyClient,
      uid: "user_123",
      docId: "user@example.com_user_123",
      message: "How am I spending this month?",
    });

    assert.strictEqual(result.isOffline, true);
    assert.strictEqual(result.offlineReason, "missing_key");
    assert.ok(loggedErrors.some((log) => log.includes("GEMINI_API_KEY missing")));
  });

  it("2. mapStatusToOfflineReason maps all required HTTP status codes accurately", () => {
    assert.strictEqual(mapStatusToOfflineReason(400), "http_400");
    assert.strictEqual(mapStatusToOfflineReason(401), "http_401");
    assert.strictEqual(mapStatusToOfflineReason(403), "http_403");
    assert.strictEqual(mapStatusToOfflineReason(404), "http_404");
    assert.strictEqual(mapStatusToOfflineReason(429), "http_429");
    assert.strictEqual(mapStatusToOfflineReason(500), "http_5xx");
    assert.strictEqual(mapStatusToOfflineReason(502), "http_5xx");
    assert.strictEqual(mapStatusToOfflineReason(503), "http_5xx");
    assert.strictEqual(mapStatusToOfflineReason(301), "other");
  });

  it("3. Sends API key in 'x-goog-api-key' header and never in URL query string", async () => {
    process.env.GEMINI_API_KEY = "test-secret-gemini-key";

    let interceptedUrl = null;
    let interceptedHeaders = null;

    setGeminiFetcher(async (url, options) => {
      interceptedUrl = url;
      interceptedHeaders = options.headers;
      return {
        ok: true,
        status: 200,
        json: async () => ({
          candidates: [
            {
              content: {
                parts: [{ text: "Here is your spending analysis." }],
              },
            },
          ],
        }),
      };
    });

    const dummyClient = {};
    const result = await runAgent({
      client: dummyClient,
      uid: "user_123",
      docId: "user@example.com_user_123",
      message: "Analyze my finances",
    });

    assert.strictEqual(result.isOffline, false);
    assert.ok(interceptedUrl.includes("https://generativelanguage.googleapis.com/v1beta/models/"));
    assert.ok(!interceptedUrl.includes("key="), "URL must not contain API key");
    assert.strictEqual(interceptedHeaders["x-goog-api-key"], "test-secret-gemini-key");
  });

  it("4. Tool declarations use 'functionDeclarations', valid types, and no forbidden fields", () => {
    assert.ok(Array.isArray(TOOL_DECLARATIONS));
    assert.ok(TOOL_DECLARATIONS[0].functionDeclarations, "Must declare via functionDeclarations");
    assert.strictEqual(TOOL_DECLARATIONS[0].function_declarations, undefined);

    const forbiddenFields = ["additionalProperties", "default", "$schema"];
    const validTypes = ["OBJECT", "STRING", "INTEGER", "NUMBER", "BOOLEAN", "ARRAY"];

    for (const tool of TOOL_DECLARATIONS[0].functionDeclarations) {
      assert.ok(tool.name, "Tool must have a name");
      assert.ok(tool.description, "Tool must have a description");
      assert.ok(tool.parameters, "Tool must have parameters");

      const paramsJson = JSON.stringify(tool.parameters);
      for (const forbidden of forbiddenFields) {
        assert.ok(
          !paramsJson.includes(`"${forbidden}"`),
          `Tool ${tool.name} parameters must not contain forbidden field '${forbidden}'`
        );
      }

      assert.ok(validTypes.includes(tool.parameters.type));
      if (tool.parameters.properties) {
        for (const [propName, propDef] of Object.entries(tool.parameters.properties)) {
          assert.ok(
            validTypes.includes(propDef.type),
            `Property ${propName} in ${tool.name} has invalid type ${propDef.type}`
          );
        }
      }
    }
  });

  it("5. When Gemini fails with HTTP 400/401/403/500, logs safe diagnostic without leaking key or URL", async () => {
    process.env.GEMINI_API_KEY = "super-secret-key-12345";

    setGeminiFetcher(async () => {
      return {
        ok: false,
        status: 400,
        text: async () =>
          JSON.stringify({
            error: {
              code: 400,
              message: "API key not valid. Please pass a valid API key.",
              status: "INVALID_ARGUMENT",
            },
          }),
      };
    });

    const result = await runAgent({
      client: dummyClient,
      uid: "user_123",
      docId: "user@example.com_user_123",
      message: "Secret prompt: transfer 5000 dollars",
    });

    assert.strictEqual(result.isOffline, true);
    assert.strictEqual(result.offlineReason, "http_400");

    // Verify safe logs
    const errorLogs = loggedErrors.join("\n");
    assert.ok(errorLogs.includes("HTTP Status: 400"));
    assert.ok(errorLogs.includes("INVALID_ARGUMENT"));
    assert.ok(errorLogs.includes("API key not valid"));
    assert.ok(!errorLogs.includes("super-secret-key-12345"), "Must not leak API key");
    assert.ok(!errorLogs.includes("Secret prompt"), "Must not leak user prompt");
    assert.ok(!errorLogs.includes("https://"), "Must not log URL");
  });

  it("6. Network timeout returns offlineReason: 'timeout'", async () => {
    process.env.GEMINI_API_KEY = "valid-key";

    setGeminiFetcher(async () => {
      const err = new Error("The operation was aborted due to timeout");
      err.name = "TimeoutError";
      throw err;
    });

    const result = await runAgent({
      client: dummyClient,
      uid: "user_123",
      docId: "user@example.com_user_123",
      message: "What is my spending?",
    });

    assert.strictEqual(result.isOffline, true);
    assert.strictEqual(result.offlineReason, "timeout");
  });
});
