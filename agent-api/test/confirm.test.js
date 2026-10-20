const { describe, it, before, afterEach } = require("node:test");
const assert = require("node:assert");
const confirmHandler = require("../api/confirm");

describe("2-Step Confirmation State Machine & Security Controls", () => {
  const TEST_PROJECT_ID = "test-pulse-project";
  let generateKeyPair;
  let SignJWT;
  let exportJWK;
  let keyPair;
  let originalFetch;

  before(async () => {
    const jose = await import("jose");
    generateKeyPair = jose.generateKeyPair;
    SignJWT = jose.SignJWT;
    exportJWK = jose.exportJWK;
    keyPair = await generateKeyPair("RS256");
    process.env.FIREBASE_PROJECT_ID = TEST_PROJECT_ID;
  });

  afterEach(() => {
    if (originalFetch) {
      globalThis.fetch = originalFetch;
      originalFetch = null;
    }
  });

  async function createValidToken(uid = "alice_123", email = "alice@example.com") {
    return new SignJWT({ sub: uid, email, auth_time: Math.floor(Date.now() / 1000) - 10 })
      .setProtectedHeader({ alg: "RS256" })
      .setIssuer(`https://securetoken.google.com/${TEST_PROJECT_ID}`)
      .setAudience(TEST_PROJECT_ID)
      .setIssuedAt()
      .setExpirationTime("1h")
      .sign(keyPair.privateKey);
  }

  function mockRequestResponse({ token, actionId }) {
    let statusCode = 200;
    let responseBody = null;

    const req = {
      method: "POST",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      body: { actionId },
    };

    const res = {
      status(c) {
        statusCode = c;
        return this;
      },
      json(b) {
        responseBody = b;
        return this;
      },
      setHeader() {
        return this;
      },
    };

    return {
      req,
      res,
      getStatus: () => statusCode,
      getBody: () => responseBody,
    };
  }

  it("Confirm success path: calls commit with budget write, status=CONFIRMED + updateTime precondition, audit log with writtenViaAgentApi: true", async () => {
    const token = await createValidToken("alice_123", "alice@example.com");
    originalFetch = globalThis.fetch;

    let commitCalled = false;
    let committedWrites = [];

    globalThis.fetch = async (url, options) => {
      // 1. Google JWKS mock fetch for token verification
      if (url.includes("googleapis.com/service_accounts/v1/jwk")) {
        const jwk = await exportJWK(keyPair.publicKey);
        jwk.alg = "RS256";
        jwk.use = "sig";
        return {
          ok: true,
          status: 200,
          json: async () => ({ keys: [jwk] }),
        };
      }

      // 2. Pending action read
      if (url.includes("pending_actions/act_success")) {
        return {
          ok: true,
          status: 200,
          json: async () => ({
            name: "projects/test-pulse-project/databases/(default)/documents/users/alice%40example.com_alice_123/pending_actions/act_success",
            fields: {
              uid: { stringValue: "alice_123" },
              status: { stringValue: "PENDING" },
              actionType: { stringValue: "CREATE_BUDGET" },
              parameters: {
                mapValue: {
                  fields: {
                    category: { stringValue: "Dining" },
                    limit: { integerValue: "4000" },
                  },
                },
              },
              expiresAt: { timestampValue: new Date(Date.now() + 600000).toISOString() },
            },
            updateTime: "2026-10-20T08:00:00.000Z",
          }),
        };
      }

      // 3. Commit call
      if (url.endsWith(":commit")) {
        commitCalled = true;
        const body = JSON.parse(options.body);
        committedWrites = body.writes;
        return {
          ok: true,
          status: 200,
          json: async () => ({ writeResults: [{ updateTime: "2026-10-20T08:05:00.000Z" }] }),
        };
      }

      throw new Error(`Unexpected fetch call in test: ${url}`);
    };

    const { req, res, getStatus, getBody } = mockRequestResponse({
      token,
      actionId: "act_success",
    });

    await confirmHandler(req, res);

    assert.strictEqual(getStatus(), 200);
    assert.strictEqual(getBody().success, true);
    assert.match(getBody().summary, /Dining.*4000/);
    assert.strictEqual(typeof getBody().auditLogId, "string");

    assert.strictEqual(commitCalled, true);
    assert.strictEqual(committedWrites.length, 3); // budget write, pending_actions update, audit_log write

    // Check budget write
    assert.match(committedWrites[0].update.name, /budgets\/dining/);

    // Check anti-replay updateTime precondition on pending action
    assert.match(committedWrites[1].update.name, /pending_actions\/act_success/);
    assert.deepStrictEqual(committedWrites[1].currentDocument, {
      updateTime: "2026-10-20T08:00:00.000Z",
    });
    assert.strictEqual(committedWrites[1].update.fields.status.stringValue, "CONFIRMED");

    // Check audit log writtenViaAgentApi: true
    assert.match(committedWrites[2].update.name, /audit_logs\//);
    assert.strictEqual(committedWrites[2].update.fields.writtenViaAgentApi.booleanValue, true);
    assert.strictEqual(committedWrites[2].update.fields.status.stringValue, "SUCCESS");
  });

  it("Replay path: status != PENDING returns 409 conflict, commit is not called", async () => {
    const token = await createValidToken("alice_123", "alice@example.com");
    originalFetch = globalThis.fetch;

    let commitCalled = false;

    globalThis.fetch = async (url) => {
      if (url.includes("googleapis.com/service_accounts/v1/jwk")) {
        const jwk = await exportJWK(keyPair.publicKey);
        jwk.alg = "RS256";
        return { ok: true, status: 200, json: async () => ({ keys: [jwk] }) };
      }

      if (url.includes("pending_actions/act_already_done")) {
        return {
          ok: true,
          status: 200,
          json: async () => ({
            name: "projects/p/databases/(default)/documents/users/u/pending_actions/act_already_done",
            fields: {
              uid: { stringValue: "alice_123" },
              status: { stringValue: "CONFIRMED" }, // Already processed!
            },
            updateTime: "2026-10-20T08:00:00.000Z",
          }),
        };
      }

      if (url.endsWith(":commit")) {
        commitCalled = true;
        return { ok: true, json: async () => ({}) };
      }

      throw new Error(`Unexpected fetch call: ${url}`);
    };

    const { req, res, getStatus, getBody } = mockRequestResponse({
      token,
      actionId: "act_already_done",
    });

    await confirmHandler(req, res);

    assert.strictEqual(getStatus(), 409);
    assert.match(getBody().error, /Action already processed/);
    assert.strictEqual(commitCalled, false);
  });

  it("Expired path: now > expiresAt marks EXPIRED, returns 410", async () => {
    const token = await createValidToken("alice_123", "alice@example.com");
    originalFetch = globalThis.fetch;

    globalThis.fetch = async (url) => {
      if (url.includes("googleapis.com/service_accounts/v1/jwk")) {
        const jwk = await exportJWK(keyPair.publicKey);
        jwk.alg = "RS256";
        return { ok: true, status: 200, json: async () => ({ keys: [jwk] }) };
      }

      if (url.includes("pending_actions/act_expired")) {
        return {
          ok: true,
          status: 200,
          json: async () => ({
            name: "projects/p/databases/(default)/documents/users/u/pending_actions/act_expired",
            fields: {
              uid: { stringValue: "alice_123" },
              status: { stringValue: "PENDING" },
              expiresAt: { timestampValue: "2020-01-01T00:00:00.000Z" }, // expired in 2020
            },
            updateTime: "2026-10-20T08:00:00.000Z",
          }),
        };
      }

      if (url.endsWith(":commit")) {
        return { ok: true, status: 200, json: async () => ({ writeResults: [{}] }) };
      }

      throw new Error(`Unexpected fetch: ${url}`);
    };

    const { req, res, getStatus, getBody } = mockRequestResponse({
      token,
      actionId: "act_expired",
    });

    await confirmHandler(req, res);

    assert.strictEqual(getStatus(), 410);
    assert.match(getBody().error, /expired/i);
  });

  it("Cross-user path: action.uid != auth.uid returns 403", async () => {
    const token = await createValidToken("bob_attacker_456", "bob@example.com");
    originalFetch = globalThis.fetch;

    globalThis.fetch = async (url) => {
      if (url.includes("googleapis.com/service_accounts/v1/jwk")) {
        const jwk = await exportJWK(keyPair.publicKey);
        jwk.alg = "RS256";
        return { ok: true, status: 200, json: async () => ({ keys: [jwk] }) };
      }

      if (url.includes("pending_actions/act_alice")) {
        return {
          ok: true,
          status: 200,
          json: async () => ({
            name: "projects/p/databases/(default)/documents/users/u/pending_actions/act_alice",
            fields: {
              uid: { stringValue: "alice_victim_123" }, // Belongs to Alice!
              status: { stringValue: "PENDING" },
            },
            updateTime: "2026-10-20T08:00:00.000Z",
          }),
        };
      }

      throw new Error(`Unexpected fetch: ${url}`);
    };

    const { req, res, getStatus, getBody } = mockRequestResponse({
      token,
      actionId: "act_alice",
    });

    await confirmHandler(req, res);

    assert.strictEqual(getStatus(), 403);
    assert.match(getBody().error, /Forbidden/i);
  });
});
