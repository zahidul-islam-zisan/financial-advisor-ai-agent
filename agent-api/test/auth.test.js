const { describe, it } = require("node:test");
const assert = require("node:assert");
const { buildUserDocId, authenticateRequest } = require("../lib/auth");

describe("Auth Middleware & Token Verification", () => {
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

  it("rejects request missing Authorization header with 401", async () => {
    let responseStatus = null;
    let responseBody = null;

    const mockReq = { headers: {} };
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

    const result = await authenticateRequest(mockReq, mockRes);

    assert.strictEqual(result, null);
    assert.strictEqual(responseStatus, 401);
    assert.match(responseBody.error, /Missing or malformed Bearer/);
  });

  it("rejects request with malformed Bearer scheme with 401", async () => {
    let responseStatus = null;
    let responseBody = null;

    const mockReq = { headers: { authorization: "Basic dXNlcjpwYXNz" } };
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

    const result = await authenticateRequest(mockReq, mockRes);

    assert.strictEqual(result, null);
    assert.strictEqual(responseStatus, 401);
  });

  it("rejects empty Bearer token with 401", async () => {
    let responseStatus = null;
    const mockReq = { headers: { authorization: "Bearer " } };
    const mockRes = {
      status(s) {
        responseStatus = s;
        return this;
      },
      json() {
        return this;
      },
    };

    const result = await authenticateRequest(mockReq, mockRes);
    assert.strictEqual(result, null);
    assert.strictEqual(responseStatus, 401);
  });
});
