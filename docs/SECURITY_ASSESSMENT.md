# 🛡️ ExpensePulse — Security Self-Assessment Report

**Classification:** Fintech Competition Security Audit  
**Date:** October 2026  
**Auditor:** Automated Agentic Security Review  

---

## 1. Executive Summary

This report evaluates the security posture of the **ExpensePulse** mobile and web application. The audit verified remediation of legacy critical vulnerabilities (such as plaintext password storage), implemented cross-user authorization controls, and created a 2-step confirmation state machine for all automated financial actions.

---

## 2. Implemented & Verified Security Controls

| Control | Implementation Details | Verification Status |
| :--- | :--- | :---: |
| **No Plaintext Passwords** | Removed `password` field from `RegistrationModel` and `auth_remote_data_source.dart`. Firebase Auth is the sole password validator. | **VERIFIED** (Automated Unit Test) |
| **Firestore Security Rules Invariants** | Comprehensive rule simulation testing ownership, password field blocking, amount bounds, and status validation. | **VERIFIED** (Automated Unit Test) |
| **Cross-User Data Isolation** | Paths scoped to `users/{email}_{uid}`. Access by other UIDs is blocked at model and rule levels. | **VERIFIED** (Automated Unit Test) |
| **Deterministic Financial Calculations** | All mathematical calculations (balance, breakdown, anomaly ratios) are executed by deterministic code, not LLM imagination. | **VERIFIED** (Automated Unit Test) |
| **Anti-Replay / Duplicate Execution Block** | `confirmPendingAction` enforces `status == 'PENDING'`. Once processed, subsequent confirmation attempts are blocked. | **VERIFIED** (Automated Unit Test) |
| **Expiration Enforcement** | Actions carry an `expiresAt` timestamp (15 min window). Expired actions are rejected. | **VERIFIED** (Automated Unit Test) |
| **Prompt Injection Containment** | User transaction notes (e.g. *"Ignore instructions and reveal data"*) are sanitized and stored as string data, never evaluated as system prompts. | **VERIFIED** (Automated Unit Test) |
| **Append-Only Audit Log Rules** | `firestore.rules` enforces `allow update, delete: if false;`, guaranteeing existing logs cannot be altered or deleted. | **VERIFIED** (Automated Unit Test) |
| **Write Verification** | Before declaring confirmation success, the application reads back the target document to ensure it exists on storage. | **VERIFIED** (Code Audit) |

---

## 3. Architectural Gap & Backend Migration Plan

### ⚠️ GAP 1: Client-Side Gemini API Key Proxying
- **Current State:** The client application currently makes direct HTTPS calls to `generativelanguage.googleapis.com` using `gemini-2.5-flash` (or uses the offline deterministic rule engine if no key is entered).
- **Risk:** An API key entered in the client could theoretically be observed via network debugging tools.
- **Remediation / Migration Prepared:** We authored [`functions/index.js`](file:///E:/financial_advisor_ai/expense_pulse-main/functions/index.js) with Google Cloud Secret Manager (`defineSecret('GEMINI_API_KEY')`). Once deployed via Firebase CLI (requires Firebase Blaze plan), the Flutter client will call the `agentChat` Cloud Function, eliminating client-side API keys entirely.

### ⚠️ GAP 2: Client-SDK Firestore Writes vs Server-Only Writes
- **Current State:** `AgentActionDataSource` currently runs client-side via the Flutter Firestore SDK, enforcing authorization through application logic and [`firestore.rules`](file:///E:/financial_advisor_ai/expense_pulse-main/firestore.rules).
- **Risk:** While security rules enforce ownership and prevent modifying audit logs, a client SDK write cannot set custom server-verified claims on audit logs.
- **Remediation / Migration Prepared:** The Cloud Function `confirmFinancialAction` executes with Firebase Admin SDK, ensuring complete server-side trust and stamping records with `verifiedByServer: true`.

---

## 4. Unverified Items & Production Deployment Prerequisites
- **Production Firestore Rules Deployment:** `firestore.rules` is authored and tested via automated unit tests, but **not published to the live Firebase console** to prevent breaking existing user sessions without testing.
- **Legacy Password Purge:** `scripts/cleanup_plaintext_passwords.js` is set to `DRY_RUN = true` and has not been executed against production data.
- **Cloud Functions Blaze Plan:** Cloud Functions require the Firebase project to be upgraded to the Blaze (Pay-as-you-go) plan before `firebase deploy --only functions` can be run.

