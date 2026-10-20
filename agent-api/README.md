# ⚡ Pulse Expense — AI Financial Assistant Agent API

> **Platform:** Vercel Serverless Functions (Node.js 20, CommonJS)  
> **Cost Profile:** 100% Free Tier compatible (Vercel Hobby + Firebase Spark Free Plan)  
> **LLM Engine:** Google Gemini 2.5 Flash (`gemini-2.5-flash` with automatic fallback to `gemini-2.5-flash-lite` and deterministic offline rule engine)  

---

## 🌟 Overview & Capabilities

This service provides a server-side AI Financial Advisor for the **Pulse Expense** Flutter application. It runs serverless on Vercel, bypassing the need for Firebase Cloud Functions (which require the paid Blaze plan).

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

1. **Authentication & Identity Derivation:**  
   Every request requires `Authorization: Bearer <Firebase ID token>`. The user's document ID is constructed strictly from the verified token:
   $$\text{docId} = \text{decodedToken.email} + \text{"\_"} + \text{decodedToken.uid}$$
   The server rejects any attempt by a client to specify or override the target `docId`.
2. **Prompt Injection Containment:**  
   All user-originated strings from Firestore (notes, category names) are sanitized (ASCII control characters removed, capped at 200 chars) and wrapped in `<data>...</data>` tags. System instructions command Gemini never to follow instructions inside `<data>` tags.
3. **PII Masking (`lib/mask.js`):**  
   Before text is sent to Google Gemini, emails, credit card / bank account numbers (13-19 digits), and phone numbers (8+ digits) are masked (`[EMAIL_REDACTED]`, `[ACCOUNT_REDACTED]`, `[PHONE_REDACTED]`).
4. **Rate Limiting (`lib/ratelimit.js`):**  
   Per-UID rate limiting enforced in Firestore `rate_limits/{uid}`: max 20 requests/minute and 200 requests/day. Returns HTTP 429 when exceeded.
5. **Two-Step Human Confirmation:**  
   Proposals expire in 15 minutes. Replay attacks are blocked by checking `status === "PENDING"`. Confirmations and cancellations run in Firestore atomic transactions that write server-verified audit records (`verifiedByServer: true`).
6. **Client Firestore Rules Hardening:**  
   > [!IMPORTANT]
   > `firestore.rules` enforces `allow write: if false` on `pending_actions`, `audit_logs`, and `rate_limits` for client SDKs. Client writes to these collections must be routed through this API.

---

## ⚙️ Environment Variables

| Variable | Description |
| :--- | :--- |
| `GEMINI_API_KEY` | Google Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey). |
| `FIREBASE_SERVICE_ACCOUNT_BASE64` | Base64-encoded string of your Firebase Admin Service Account JSON. |
| `GEMINI_MODEL` | *(Optional)* Model ID (default: `gemini-2.5-flash`). |

---

## 🔑 Generating the Firebase Service Account Key

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Click **Project Settings** (gear icon) ➔ **Service accounts** tab.
3. Under **Firebase Admin SDK**, select **Node.js** and click **Generate new private key**.
4. Save the downloaded JSON file locally (e.g. `service-account.json`). **NEVER commit this file to Git.**
5. Convert the JSON file into a Base64 string:

#### On Windows (PowerShell):
```powershell
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes("service-account.json")) | Set-Clipboard
# The base64 string is now copied to your clipboard!
```

#### On macOS / Linux (Terminal):
```bash
base64 -w 0 service-account.json | pbcopy # (or xclip -selection clipboard)
```

---

## 🚀 Deployment to Vercel (Hobby Free Plan)

### Step 1: Push Code & Connect Vercel
1. Push your repository to GitHub.
2. Go to [Vercel](https://vercel.com/) and click **Add New** ➔ **Project**.
3. Import your `pulse_expense` repository.

### Step 2: Configure Root Directory
In the Vercel project configuration screen:
- **Root Directory:** Set to `agent-api` *(Click Edit and select the `agent-api` folder)*.
- **Framework Preset:** `Other`.

### Step 3: Add Environment Variables
Under **Environment Variables**, add:
- `GEMINI_API_KEY`: *(Your Google AI Studio key)*
- `FIREBASE_SERVICE_ACCOUNT_BASE64`: *(The Base64 string generated above)*
- `GEMINI_MODEL`: `gemini-2.5-flash`

Click **Deploy**!

---

## 🧪 Testing Locally

Run the complete zero-network test suite:
```bash
cd agent-api
npm test
```
All 19 unit tests validate authentication, state machine transitions, math accuracy, anomaly thresholds, recurring bills detection, injection defense, and PII masking.

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
  "timestamp": "2026-10-20T07:20:00.000Z"
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
