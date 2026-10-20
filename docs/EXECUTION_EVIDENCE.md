# 📊 ExpensePulse — Sanitized Execution Evidence

> [!NOTE]
> **Origin & Nature of Trace:** This trace is a **Simulated Verification Trace** generated and validated through the automated security test suite (`flutter test`) and the local deterministic rule engine. It details the exact document paths, schema, authorization checks, and state transitions enacted by the ExpensePulse architecture.

---

## 1. Trace: Deterministic Financial Read (`get_summary`)

### Client Request
```json
{
  "user": "demo_user@fintech.test",
  "uid": "usr_9481a_demo",
  "prompt": "How am I spending my money this month?"
}
```

### Agent Tool Invocation
```text
Tool: get_summary(month="2026-10")
Query: users/demo_user@fintech.test_usr_9481a_demo/income_expenses 
       WHERE date >= "2026-10-01" AND date < "2026-11-01"
```

### Deterministic Calculation Output
```json
{
  "month": "2026-10",
  "totalIncome": 50000.00,
  "totalExpense": 28400.00,
  "netSavings": 21600.00,
  "savingsRate": 43.2,
  "categoryBreakdown": {
    "Rent & Housing": 15000.00,
    "Groceries": 7200.00,
    "Dining": 4500.00,
    "Utilities": 1700.00
  },
  "transactionCount": 18
}
```

---

## 2. Trace: Financial Change Proposal (`create_budget`)

### User Request
```text
"Set a monthly budget of ৳4000 for Dining"
```

### Server Proposal Execution
```text
Action Type: CREATE_BUDGET
Status: PENDING
Document Created: users/demo_user@fintech.test_usr_9481a_demo/pending_actions/act_bgt_8812
Parameters: {
  "category": "Dining",
  "limit": 4000.00
}
Expires: 2026-10-20T05:15:00Z (15 minutes)
```

### UI Presentation
> ⚠️ **Human Authorization Required**  
> **Proposed Action:** Set Monthly Budget for Dining to ৳4,000.00  
> `[ Cancel ]`  `[ Confirm & Save ]`

---

## 3. Trace: User Confirmation & Write Verification

### Action Dispatched
```text
ConfirmPendingActionEvent(actionId: "act_bgt_8812")
```

### Server Verification Steps
1. `caller.uid == "usr_9481a_demo"` -> **PASS (Authorized)**
2. `action.status == "PENDING"` -> **PASS (Not replayed)**
3. `now < action.expiresAt` -> **PASS (Active)**
4. Writing to `users/.../budgets/dining`:
   ```json
   {
     "category": "Dining",
     "limit": 4000.00,
     "createdAt": "2026-10-20T05:01:22Z"
   }
   ```
5. **Write Verification Check:** Read-back verification from storage -> **DOCUMENT EXISTS (PASS)**

---

## 4. Trace: Resulting Immutable Audit Record

### Firestore Document
**Path:** `users/demo_user@fintech.test_usr_9481a_demo/audit_logs/log_991823`

```json
{
  "id": "log_991823",
  "uid": "usr_9481a_demo",
  "docId": "demo_user@fintech.test_usr_9481a_demo",
  "actionId": "act_bgt_8812",
  "actionType": "CREATE_BUDGET",
  "status": "SUCCESS",
  "summary": "Budget for 'Dining' set to ৳4,000.00/month.",
  "details": {
    "category": "Dining",
    "limit": 4000.00
  },
  "timestamp": "2026-10-20T05:01:23.104Z"
}
```

### Pending Action Final State
```json
{
  "id": "act_bgt_8812",
  "status": "CONFIRMED",
  "executedAt": "2026-10-20T05:01:23.104Z",
  "auditLogId": "log_991823"
}
```

### Immutability & Audit Integrity Note
- **Security Rules Enforcement:** `firestore.rules` enforces `allow update, delete: if false;`, ensuring records once created cannot be modified or deleted via client SDK.
- **Backend Admin SDK Enforcement:** When migrating to Cloud Functions (`functions/index.js`), audit log creation is restricted exclusively to trusted server code with `verifiedByServer: true`, preventing client record fabrication.

