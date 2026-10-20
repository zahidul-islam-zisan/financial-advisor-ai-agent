const { describe, it, before } = require("node:test");
const assert = require("node:assert");
const { buildUserDocId, verifyFirebaseToken, authenticateRequest } = require("../lib/auth");

describe("Auth Middleware & Token Verification", () => {
  const TEST_PROJECT_ID = "test-pulse-project";
  let generateKeyPair;
  let SignJWT;
  let keyPair;
  let publicKey;

  before(async () => {
    const jose = await import("jose");
    generateKeyPair = jose.generateKeyPair;
    SignJWT = jose.SignJWT;
    keyPair = await generateKeyPair("RS256");
    publicKey = keyPair.publicKey;
  });

  async function createTestToken(claims = {}, options = {}) {
    const defaultClaims = {
      sub: "user_test_123",
      email: "alice@example.com",
      auth_time: Math.floor(Date.now() / 1000) - 10,
      ...claims,
    };

    const jwt = new SignJWT(defaultClaims)
      .setProtectedHeader({ alg: "RS256" })
      .setIssuer(options.issuer || `https://securetoken.google.com/${TEST_PROJECT_ID}`)
      .setAudience(options.audience || TEST_PROJECT_ID)
      .setIssuedAt();

    if (options.expired) {
      jwt.setExpirationTime(Math.floor(Date.now() / 1000) - 60); // 1 min ago
    } else {
      jwt.setExpirationTime(options.expiration || "1h");
    }

    return jwt.sign(keyPair.privateKey);
  }

  it("buildUserDocId constructs exact legacy format: ${email}_${uid}", () => {
    const docId = buildUserDocId({
      uid: "usr_12345",
      email: "Zahidul@Example.COM",
    });

    assert.strictEqual(docId, "zahidul@example.com_usr_12345");
  });

  it("buildUserDocId handles missing or empty email cleanly", () => {
    const docId = buildUserDocId({
      uid: "usr_99999",
      email: "",
    });

    assert.strictEqual(docId, "_usr_99999");
  });

  it("valid RS256 token passes verification and extracts user identity", async () => {
    const token = await createTestToken({ sub: "user_alice_456", email: "alice.test@example.com" });
    const verified = await verifyFirebaseToken(token, {
      projectId: TEST_PROJECT_ID,
      jwks: publicKey,
    });

    assert.strictEqual(verified.uid, "user_alice_456");
    assert.strictEqual(verified.email, "alice.test@example.com");
    assert.strictEqual(verified.docId, "alice.test@example.com_user_alice_456");
    assert.strictEqual(verified.idToken, token);
  });

  it("rejects expired token with generic 401 without internal leak", async () => {
    const expiredToken = await createTestToken({}, { expired: true });

    let responseStatus = null;
    let responseBody = null;

    const mockReq = { headers: { authorization: `Bearer ${expiredToken}` } };
    const mockRes = {
      status(s) {
        responseStatus = s;
        return this;
      },
      json(b) {
        responseBody = b;
        return this;
      },
    };

    const result = await authenticateRequest(mockReq, mockRes, {
      projectId: TEST_PROJECT_ID,
      jwks: publicKey,
    });

    assert.strictEqual(result, null);
    assert.strictEqual(responseStatus, 401);
    assert.strictEqual(responseBody.error, "Unauthorized: Invalid, expired, or unverified Firebase ID token.");
  });

  it("rejects token with wrong audience", async () => {
    const wrongAudToken = await createTestToken({}, { audience: "wrong-project-id" });

    let responseStatus = null;
    let responseBody = null;

    const mockReq = { headers: { authorization: `Bearer ${wrongAudToken}` } };
    const mockRes = {
      status(s) { responseStatus = s; return this; },
      json(b) { responseBody = b; return this; },
    };

    const result = await authenticateRequest(mockReq, mockRes, {
      projectId: TEST_PROJECT_ID,
      jwks: publicKey,
    });

    assert.strictEqual(result, null);
    assert.strictEqual(responseStatus, 401);
    assert.strictEqual(responseBody.error, "Unauthorized: Invalid, expired, or unverified Firebase ID token.");
  });

  it("rejects token with wrong issuer", async () => {
    const wrongIssToken = await createTestToken({}, { issuer: "https://evil.issuer.com" });

    let responseStatus = null;
    const mockReq = { headers: { authorization: `Bearer ${wrongIssToken}` } };
    const mockRes = {
      status(s) { responseStatus = s; return this; },
      json() { return this; },
    };

    const result = await authenticateRequest(mockReq, mockRes, {
      projectId: TEST_PROJECT_ID,
      jwks: publicKey,
    });

    assert.strictEqual(result, null);
    assert.strictEqual(responseStatus, 401);
  });

  it("rejects token missing email claim", async () => {
    const noEmailToken = await createTestToken({ email: null });

    let responseStatus = null;
    const mockReq = { headers: { authorization: `Bearer ${noEmailToken}` } };
    const mockRes = {
      status(s) { responseStatus = s; return this; },
      json() { return this; },
    };

    const result = await authenticateRequest(mockReq, mockRes, {
      projectId: TEST_PROJECT_ID,
      jwks: publicKey,
    });

    assert.strictEqual(result, null);
    assert.strictEqual(responseStatus, 401);
  });

  it("docId is always derived strictly from token claims and ignores request body", async () => {
    const token = await createTestToken({ sub: "real_uid_123", email: "real@example.com" });

    const mockReq = {
      headers: { authorization: `Bearer ${token}` },
      body: { docId: "attacker_spoofed_doc_id", uid: "victim_uid" },
    };
    const mockRes = {
      status() { return this; },
      json() { return this; },
    };

    const verified = await authenticateRequest(mockReq, mockRes, {
      projectId: TEST_PROJECT_ID,
      jwks: publicKey,
    });

    assert.strictEqual(verified.docId, "real@example.com_real_uid_123");
    assert.strictEqual(verified.uid, "real_uid_123");
    assert.notStrictEqual(verified.docId, mockReq.body.docId);
  });

  it("rejects request missing Authorization header with 401", async () => {
    let responseStatus = null;
    let responseBody = null;

    const mockReq = { headers: {} };
    const mockRes = {
      status(s) { responseStatus = s; return this; },
      json(b) { responseBody = b; return this; },
    };

    const result = await authenticateRequest(mockReq, mockRes);
    assert.strictEqual(result, null);
    assert.strictEqual(responseStatus, 401);
    assert.match(responseBody.error, /Missing or malformed Bearer/);
  });

  it("rejects request with malformed Bearer scheme with 401", async () => {
    let responseStatus = null;
    const mockReq = { headers: { authorization: "Basic dXNlcjpwYXNz" } };
    const mockRes = {
      status(s) { responseStatus = s; return this; },
      json() { return this; },
    };

    const result = await authenticateRequest(mockReq, mockRes);
    assert.strictEqual(result, null);
    assert.strictEqual(responseStatus, 401);
  });

  it("rejects empty Bearer token with 401", async () => {
    let responseStatus = null;
    const mockReq = { headers: { authorization: "Bearer " } };
    const mockRes = {
      status(s) { responseStatus = s; return this; },
      json() { return this; },
    };

    const result = await authenticateRequest(mockReq, mockRes);
    assert.strictEqual(result, null);
    assert.strictEqual(responseStatus, 401);
  });
});
