# ⚡ Pulse Expense — AI Financial Assistant Agent API

> **Platform:** Vercel Serverless Functions (Node.js 20, CommonJS)  
> **Auth & Database:** Direct Firebase ID Token Verification (`jose` + Google JWKS) & Firestore REST API (Acts as signed-in user; zero service account keys required)  
> **Cost Profile:** 100% Free Tier compatible (Vercel Hobby + Firebase Spark Free Plan)  
> **LLM Engine:** Google Gemini 3.5 Flash (`gemini-3.5-flash` with automatic fallback to `gemini-3.5-flash-lite` and deterministic offline rule engine)  

---

## 🌟 Overview & Capabilities

This service provides a serverless AI Financial Advisor backend for the **Pulse Expense** Flutter application.

It operates without requiring a Firebase Service Account or the `firebase-admin` SDK. Instead, it:
1. Verifies the user's Firebase ID Token locally via Google's public JSON Web Key Set (JWKS) using `jose`.
2. Interacts with Cloud Firestore via the official **Firestore REST API** using the user's own Bearer ID token. All Firestore Security Rules are automatically enforced against the authenticated user.

### Deterministic Tool Tiers:
- **Tier 1 (Read-Only, Automated Execution):**
  1. `get_summary(month)`: Monthly income, expenses, net savings, savings rate, and category percentage breakdown.
  2. `get_transactions(month, category, limit)`: Retrieves recent transactions sorted in-memory.
  3. `find_unusual_spending(month)`: Detects transactions $\ge 1.5\times$ historical category averages ($\ge 3$ samples).
  4. `detect_recurring_bills()`: Clusters expenses across 2+ distinct months to identify recurring utilities and subscriptions.
  5. `analyze_bill(title)`: Month-over-month trend and % variance for a specific vendor or bill.
  6. `forecast_next_month()`: 3-month moving average per category for proactive cashflow projections.
  7. `propose_budget()`: Proposes category budget caps based on historical averages and 50/30/20 sanity checks (does not write).
  8. `get_budget_status()`: Compares current month spending against established limits; generates 80% and 100% threshold alerts.
- **Tier 2 (Proposals Requiring Human Confirmation):**
  1. `create_budget(category, limit)`: Creates a temporary 15-minute `PENDING` proposal in Firestore.
  2. `create_savings_goal(goalName, targetAmount, targetMonths)`: Creates a `PENDING` savings proposal.
- **No Tier 3 Capability:**
  The agent has **zero deletion or export privileges**. It cannot delete transactions, wipe user budgets, or export raw database collections.

---

## 🛡️ Security & Privacy Engineering

1. **Authentication & Identity Derivation (`lib/auth.js`):**  
   Every request requires `Authorization: Bearer <Firebase ID token>`. Verified against Google's public certificates with checks for:
   - Algorithm `RS256`
   - Issuer `https://securetoken.google.com/<FIREBASE_PROJECT_ID>`
   - Audience `<FIREBASE_PROJECT_ID>`
   - Expiration and valid timestamp
   - Non-empty subject (`sub` / `uid`) and required `email` claim.
   The user's root document ID is constructed strictly from the verified claims:
   $$\text{docId} = \text{decodedToken.email} + \text{"\_"} + \text{decodedToken.uid}$$
   The server rejects any attempt by a client body to specify or override the target `docId`.

2. **Prompt Injection Containment (`lib/guard.js`):**  
   All user-originated strings from Firestore (notes, category names) are sanitized (ASCII control characters stripped, capped at 200 chars) and enclosed in `<data>...</data>` tags. System instructions command Gemini never to follow instructions inside `<data>` tags.

3. **PII Masking (`lib/mask.js`):**  
   Before text is sent to Google Gemini, emails, credit card / bank account numbers (13-19 digits), and phone numbers (8+ digits) are masked (`[EMAIL_REDACTED]`, `[ACCOUNT_REDACTED]`, `[PHONE_REDACTED]`).

4. **Atomic Anti-Replay Confirmation (`api/confirm.js` & `api/cancel.js`):**  
   Pending actions are bound to a 15-minute expiration window. When a user confirms or cancels an action, the endpoint submits an atomic commit to Firestore REST with a precondition check:
   ```json
   "currentDocument": { "updateTime": "<capturedUpdateTime>" }
   ```
   If a duplicate or concurrent request attempts to process the action, Firestore rejects the commit with a precondition failure, preventing replay attacks.

5. **Known Risks & Security Trade-offs:**
   > [!IMPORTANT]
   > - **Append-Only Audit Logs:** Since this architecture runs on the Spark free plan without server-privileged Admin SDK credentials, Firestore security rules enforce append-only logging (`create` allowed with matching `uid`, `update` and `delete` disallowed). However, a malicious client possessing a valid ID token could write its own record directly to `audit_logs`. Full cryptographic tamper-proofing requires Cloud Functions / Admin SDK on a paid plan.
   > - **In-Memory Rate Limiting:** Enforces 20 req/min and 200 req/day per UID in an in-memory Map (`lib/ratelimit.js`) on a best-effort basis per serverless container instance, rather than a shared database collection.

---

## ⚙️ Environment Variables

| Variable | Description |
| :--- | :--- |
| `GEMINI_API_KEY` | Google Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey). |
| `FIREBASE_PROJECT_ID` | Your Firebase Project ID (e.g. `pulse-expense-3156f`). |
| `GEMINI_MODEL` | *(Optional)* Model ID (default: `gemini-2.5-flash`). |

---

## 🚀 Deployment to Vercel (Hobby Free Plan)

### Step 1: Push Code & Connect Vercel
1. Push your repository to GitHub.
2. Go to [Vercel](https://vercel.com/) and click **Add New** ➔ **Project**.
3. Import your `financial-advisor-ai-agent` repository.

### Step 2: Configure Root Directory
In the Vercel project configuration screen:
- **Root Directory:** Set to `agent-api` *(or `expense_pulse-main/agent-api` depending on your repo root)*.
- **Framework Preset:** `Other`.

### Step 3: Add Environment Variables
Under **Environment Variables**, add:
- `GEMINI_API_KEY`: *(Your Google AI Studio key)*
- `FIREBASE_PROJECT_ID`: *(Your Firebase Project ID, e.g. `pulse-expense-3156f`)*
- `GEMINI_MODEL`: `gemini-3.5-flash` (optional, defaults to `gemini-3.5-flash`)

Click **Deploy**!

---

## 🧪 Testing Locally

Run the complete zero-network test suite:
```bash
cd agent-api
npm test
```
All unit tests validate JWKS RS256 token verification, Firestore REST converters and preconditions, state machine transitions, math accuracy, anomaly thresholds, recurring bills detection, injection defense, and PII masking.

---

## 📡 Sample cURL Requests

### 1. Health Check
```bash
curl -X GET https://your-agent-api.vercel.app/api/health
```
**Response:**
```json
{
  "ok": true,
  "service": "pulse-expense-agent-api",
  "version": "1.0.0",
  "timestamp": "2026-10-20T08:15:00.000Z"
}
```

### 2. Chat with Pulse AI
```bash
curl -X POST https://your-agent-api.vercel.app/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <FIREBASE_ID_TOKEN>" \
  -d '{
    "message": "How am I spending my money this month?",
    "history": []
  }'
```
**Response:**
```json
{
  "reply": "📊 Financial Overview for 2026-10:\n1. Total Income: ৳50,000.00\n2. Total Expenses: ৳28,400.00\n3. Net Savings: ৳21,600.00 (Savings rate: 43.2%)\n\nThis is a suggestion, not professional financial advice.",
  "toolCalls": [
    { "name": "get_summary", "args": { "month": "2026-10" }, "tier": 1 }
  ],
  "pendingAction": null,
  "isOffline": false
}
```

### 3. Propose & Confirm a Budget
```bash
# Step 1: Propose via chat
curl -X POST https://your-agent-api.vercel.app/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <FIREBASE_ID_TOKEN>" \
  -d '{
    "message": "Set a monthly budget for Dining at ৳4000"
  }'

# Step 2: Confirm action with actionId received in pendingAction
curl -X POST https://your-agent-api.vercel.app/api/confirm \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <FIREBASE_ID_TOKEN>" \
  -d '{
    "actionId": "act_88192a"
  }'
```
**Response:**
```json
{
  "success": true,
  "summary": "Budget for 'Dining' successfully set to ৳4000.00/month.",
  "auditLogId": "log_9921b"
}
```

### 4. Cancel a Pending Action
```bash
curl -X POST https://your-agent-api.vercel.app/api/cancel \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <FIREBASE_ID_TOKEN>" \
  -d '{
    "actionId": "act_88192a"
  }'
```
