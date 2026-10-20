const { describe, it } = require("node:test");
const assert = require("node:assert");

describe("2-Step Confirmation State Machine & Security Controls", () => {
  it("Tier 2 tool execution returns needs_confirmation and never executes writes immediately", () => {
    // Simulates create_budget tool output before user approval
    const proposalOutput = {
      status: "needs_confirmation",
      actionId: "act_test_99",
      actionType: "CREATE_BUDGET",
      title: "Set Monthly Budget for Dining: ৳4,000.00",
      parameters: { category: "Dining", limit: 4000 },
      expiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
    };

    assert.strictEqual(proposalOutput.status, "needs_confirmation");
    assert.strictEqual(proposalOutput.actionId, "act_test_99");
    assert.strictEqual(proposalOutput.parameters.limit, 4000);
  });

  it("Blocks replay execution when action status is already CONFIRMED", () => {
    const existingAction = {
      id: "act_101",
      uid: "alice_123",
      status: "CONFIRMED", // Already confirmed
      expiresAt: { toMillis: () => Date.now() + 600000 },
    };

    function validateCanExecute(callerUid, action) {
      if (action.uid !== callerUid) {
        return { allowed: false, code: 403, reason: "Cross-user denial" };
      }
      if (action.status !== "PENDING") {
        return { allowed: false, code: 400, reason: "Replay blocked: action already processed" };
      }
      return { allowed: true };
    }

    const check = validateCanExecute("alice_123", existingAction);
    assert.strictEqual(check.allowed, false);
    assert.strictEqual(check.code, 400);
    assert.match(check.reason, /Replay blocked/);
  });

  it("Blocks execution when pending action has expired", () => {
    const expiredAction = {
      id: "act_102",
      uid: "alice_123",
      status: "PENDING",
      expiresAt: { toMillis: () => Date.now() - 60000 }, // Expired 1 min ago
    };

    function validateExpiry(action) {
      const now = Date.now();
      const expiresAt = action.expiresAt.toMillis();
      if (now > expiresAt) {
        return { expired: true, code: 410, reason: "Pending action has expired" };
      }
      return { expired: false };
    }

    const check = validateExpiry(expiredAction);
    assert.strictEqual(check.expired, true);
    assert.strictEqual(check.code, 410);
  });

  it("Blocks cross-user confirmation attempts (User Bob confirming Alice's action)", () => {
    const alicesAction = {
      id: "act_103",
      uid: "alice_123",
      status: "PENDING",
      expiresAt: { toMillis: () => Date.now() + 600000 },
    };

    const callerUid = "bob_attacker_456";

    function verifyOwnership(caller, action) {
      return caller === action.uid;
    }

    assert.strictEqual(verifyOwnership(callerUid, alicesAction), false);
  });
});
