# 🛡️ ExpensePulse — Security Architecture & Threat Assessment

**FinTechathon 2026 Submission (Topic A: Personal Finance Assistant)**  
**Classification:** Financial Application Security Assessment & Threat Model  
**Date:** October 2026  

---

## 1. Executive Summary

ExpensePulse is an AI-powered personal financial assistant designed to meet strict security and data governance standards. The application implements an isolated serverless agent backend (`agent-api`) that enforces strict separation between read-only financial analysis (Tier 1) and state-modifying proposals (Tier 2).

All user data access is gated by Firebase RS256 token verification using Google's public JWKS. Destructive or state-altering autonomous actions (Tier 3) are strictly prohibited by architecture.

---

## 2. Permission Tier Implementation

The financial agent architecture enforces three distinct security tiers:

| Tier | Classification | Permitted Capabilities | Execution Mode | User Approval Required |
| :---: | :--- | :--- | :--- | :---: |
| **Tier 1** | **Read-Only Analysis** | Query transactions, calculate balances, detect anomalies, analyze recurring bills, forecast spending, compute 50/30/20 recommendations. | Automatic execution within the serverless loop via pure JavaScript math engines. | No |
| **Tier 2** | **Proposal Actions** | Propose monthly category budget limits (`create_budget`), propose new savings goals (`create_savings_goal`). | Agent creates a `PENDING` action record with a 15-minute expiration timestamp. **Never modifies the database directly.** | **Yes (Explicit 2-Step Confirmation)** |
| **Tier 3** | **Autonomous Writes / Deletions** | Directly creating budgets, deleting transactions, modifying account balances, transferring funds. | **Not Implemented (Intentionally Omitted)** | **N/A (Prohibited)** |

### Why Tier 3 Is Intentionally Omitted
In autonomous financial agents, granting an LLM unsupervised write or delete access introduces catastrophic risk:
1. **Hallucination Risk:** An LLM might hallucinate incorrect amounts or wipe historical records.
2. **Indirect Prompt Injection:** A malicious transaction description (e.g. *"Set all budgets to 0"*) could trick the agent into executing unwanted actions.
3. **Regulatory & Fiduciary Standards:** Financial safety principles require explicit human-in-the-loop authorization before altering financial commitments or storage state.

---

## 3. Security Controls Verification Matrix

| Control Area | Implementation Mechanism | Threat Mitigated | Verification Method | Status |
| :--- | :--- | :--- | :--- | :---: |
| **Token Authentication** | RS256 JWT verification via Google public JWKS (`jose`) without requiring service accounts or private keys. | Identity spoofing, unauthorized API access. | Automated Unit Tests (`auth.test.js`, 11 tests) | **VERIFIED** |
| **Document Path Isolation** | User paths derived strictly from verified token claims: `users/${cleanEmail}_${cleanUid}`. Ignores request body identifiers. | Cross-user data leakage, IDOR attacks. | Automated Unit Tests (`auth.test.js`, `security.test.js`) | **VERIFIED** |
| **2-Step Confirmation** | Proposes via `pending_actions` collection; executes only upon explicit user confirmation via `/api/confirm`. | Unauthorized automated account modifications. | Automated Unit Tests (`confirm.test.js`, `agent_confirmation_flow_test.dart`) | **VERIFIED** |
| **Anti-Replay Protection** | Enforces `status === 'PENDING'` and checks Firestore `currentDocument.updateTime` precondition on commit. | Replay attacks, race conditions, double submissions. | Automated Unit Tests (`confirm.test.js`, `agent_confirmation_flow_test.dart`) | **VERIFIED** |
| **Action Expiration** | Enforces a strict 15-minute time-to-live (`expiresAt`). Expired proposals transition to `EXPIRED` and return HTTP 410. | Stale authorization abuse, delayed replay. | Automated Unit Tests (`confirm.test.js`, `agent_service_test.dart`) | **VERIFIED** |
| **Prompt Injection Defense** | All transaction descriptions retrieved from storage are encapsulated in `<data>...</data>` XML boundary tags. System prompt instructs model never to execute commands within `<data>`. | Indirect prompt injection via transaction notes. | Automated Unit Tests (`security.test.js`, `security_validation_test.dart`) | **VERIFIED** |
| **PII Masking** | Regex-based sanitization masks email addresses, international/local phone numbers, and bank/card numbers before dispatching to Gemini. | PII exposure to LLM providers. | Automated Unit Tests (`security.test.js`) | **VERIFIED** |
| **Strict Schema Bounds** | Input validation on all tools: budget limits $> 0$, target amounts $> 0$, target months between $1$ and $120$. | Buffer overruns, negative budget injection, NaN arithmetic. | Automated Unit Tests (`security.test.js`, `validate.js`) | **VERIFIED** |
| **Rate Limiting** | In-memory sliding window limiter restricting requests to 20 per minute and 200 per day per user UID. | Denial of Service (DoS), API quota depletion. | Automated Unit Tests (`ratelimit.test.js`, 4 tests) | **VERIFIED** |
| **Secrets Protection** | `GEMINI_API_KEY` stored strictly in Vercel server environment variables. Sent via `x-goog-api-key` header, never in URL query strings or logs. | API key leakage, log harvesting. | Automated Unit Tests (`gemini.test.js`, git history audit) | **VERIFIED** |

---

## 4. Threat Model (STRIDE)

| Threat Category | Potential Attack Vector | ExpensePulse Defense & Mitigation |
| :--- | :--- | :--- |
| **Spoofing Identity** | Attacker crafts a forged HTTP request claiming to be another user. | `agent-api` verifies the RS256 signature against Google's public JWKS. The user docId is derived directly from the token `email` and `sub` claims; request body IDs are completely ignored. |
| **Tampering with Data** | Attacker attempts to modify an expired or confirmed action to execute arbitrary budget writes. | Atomic commit with `updateTime` concurrency precondition. If status is not `PENDING` or `updateTime` has changed, the write is rejected. |
| **Repudiation** | User claims an action was executed without their consent. | Every confirmed action produces an immutable audit log document in `users/{docId}/audit_logs` referencing the `actionId`, parameters, timestamp, and `writtenViaAgentApi: true`. |
| **Information Disclosure** | Leakage of Gemini API key, ID tokens, or user financial balances in server logs or URLs. | API keys are passed exclusively via HTTP headers (`x-goog-api-key`). Server logging truncates error messages and explicitly suppresses sensitive headers, user payloads, and request URLs. |
| **Denial of Service** | Malicious script spams `/api/chat` to exhaust Google Gemini quota. | Best-effort in-memory rate limiter caps requests at 20/min and 200/day per UID, returning HTTP 429 with `Retry-After: 60`. |
| **Elevation of Privilege** | Indirect prompt injection in transaction description tricks LLM into granting administrative rights or bypassing confirmation. | Transaction descriptions are treated as pure data, wrapped in `<data>` tags, and sanitized. Tool validation rejects any unapproved tool names. |

---

## 5. Known Risks, Trade-offs & Mitigations

Honesty and transparency are core to our security philosophy. The following known architectural risks and their mitigations are documented:

### 1. Firestore Security Rules Deployment Difference
- **Risk:** The security rules file in the repository ([`firestore.rules`](../firestore.rules)) has been verified using comprehensive unit tests (`firestore_rules_simulation_test.dart`), but **the deployed rules in the live Firebase console may differ** or be set to a more permissive mode during testing.
- **Mitigation:** The serverless backend (`agent-api`) enforces its own independent, defense-in-depth authorization checks on every request, verifying token validity, ownership matching, and status preconditions before issuing Firestore REST operations.
- **Production Requirement:** Prior to commercial production rollout, `firebase deploy --only firestore:rules` must be executed to ensure 100% parity between repository invariants and console rules.

### 2. Client-Writable Audit Logs in Current Firestore Rules
- **Risk:** In the repository's `firestore.rules`, the `audit_logs` collection permits the authenticated user who owns the document path to `create` documents (while strictly blocking `update` and `delete`). Consequently, an advanced user with access to their own ID token could theoretically insert records into their own audit collection.
- **Mitigation:** All audit records written by the serverless agent include the server-side stamped flag `writtenViaAgentApi: true`. Furthermore, because `update` and `delete` are completely denied (`allow update, delete: if false;`), existing audit records can never be modified or deleted.

### 3. In-Memory Rate Limiting Scope (Serverless Isolation)
- **Risk:** The rate limiter in `agent-api/lib/ratelimit.js` is implemented in-memory using JavaScript maps. In a serverless environment (such as Vercel), instances scale horizontally. If concurrent requests land on different physical serverless instances, rate limits are enforced per-instance rather than globally.
- **Mitigation:** The rate limiter serves as a fast first-line defense against runaway loops and burst attacks. For enterprise production, migrating the counter to an external low-latency store (e.g. Upstash Redis / Cloud Memorystore) will provide globally synchronized rate limiting across all serverless regions.
