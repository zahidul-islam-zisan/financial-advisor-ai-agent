# 💎 ExpensePulse — AI Financial Advisor & Smart Budget Copilot

> **Fintech Competition Edition**  
> *An intelligent personal finance and budgeting mobile/web application powered by Flutter, Firebase, and Google Gemini 2.5 Flash.*

---

## 🌟 Overview & Key Features

ExpensePulse (`expense_tracker_app`) is an intelligent financial management platform combining deterministic expense tracking with an AI Financial Copilot.

- **Dual Transaction Tracking:** Log daily income and expenses categorized with custom tags.
- **Visual Analytics:** Interactive monthly cashflow charts, category percentage distributions, and dynamic budgeting summaries.
- **Pulse AI Financial Copilot:** Powered by Google Gemini 2.5 Flash with function calling and deterministic fallback.
- **2-Step Human Confirmation:** Proposes budgets and savings goals as pending proposals that require explicit user confirmation before writing to Firestore.
- **Immutable Audit Logging:** Every confirmed financial action generates a tamper-evident audit record.
- **Cross-User Data Isolation:** Enforced at the application, model, and Firestore Security Rules layer.

---

## 🏗️ Architecture & Tech Stack

```
┌─────────────────────────────────────────────────────────────┐
│                       Flutter UI Layer                      │
│   (BlocConsumer, MeshBackground, Interactive AI Bubble)     │
└──────────────────────────────┬──────────────────────────────┘
                               │ Dispatches Events
┌──────────────────────────────▼──────────────────────────────┐
│                      State Management                       │
│        (Bloc & MultiBlocProvider: Auth, AI, Category, etc.) │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
┌──────────────▼─────────────┐ ┌──────────────▼───────────────┐
│     Google Gemini AI       │ │   AgentActionDataSource      │
│  (2.5 Flash + Tools /      │ │   (Deterministic Engine:     │
│   Function Calling)        │ │    Summary, Spikes, Anomaly) │
└──────────────┬─────────────┘ └──────────────┬───────────────┘
               │ Returns FunctionCall / Intent │
┌──────────────▼──────────────────────────────▼───────────────┐
│              Two-Step Human Confirmation Engine             │
│   PendingAction (15m expiry) ──► User Confirms ──► Write    │
└──────────────────────────────┬──────────────────────────────┘
                               │ Verified Writes & Audit Log
┌──────────────────────────────▼──────────────────────────────┐
│                     Cloud Firestore                         │
│  users/{email}_{uid}/                                       │
│   ├── profile/info                                          │
│   ├── categories/                                           │
│   ├── income_expenses/                                      │
│   ├── budgets/                                              │
│   ├── savings_goals/                                        │
│   ├── pending_actions/                                      │
│   └── audit_logs/ (immutable append-only)                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Getting Started & Running Locally

### Prerequisites
- **Flutter SDK:** `^3.41.0` (Dart `^3.11.0`)
- **Node.js:** `v18+` / `v24+` (for Cloud Functions and scripts)

### Installation
```bash
# Clone and enter directory
cd expense_pulse-main

# Get Flutter dependencies
flutter pub get
```

### Firebase Configuration Setup
For security, live credentials (`android/app/google-services.json` and `lib/firebase_options.dart`) are excluded from Git. Sanitized templates are provided at:
- `android/app/google-services.example.json`
- `lib/firebase_options.example.dart`

To generate your own credentials for your Firebase project:
```bash
# 1. Install FlutterFire CLI (if not already installed)
dart pub global activate flutterfire_cli

# 2. Run configuration wizard
flutterfire configure
```
This automatically registers the app in your Firebase project and generates `lib/firebase_options.dart` and `android/app/google-services.json`.

### Running the Application

#### 1. In Google Chrome
```bash
flutter run -d chrome
```

#### 2. On Local Wi-Fi (Mobile Access)
```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```
Open `http://<YOUR_LOCAL_IP>:8080` in your mobile browser.

---

## 🧪 Testing & Verification

Run the full automated test suite (including deterministic financial calculations, security validation, and agent confirmation state machine):

```bash
flutter test
```

Run static code analysis:
```bash
flutter analyze --no-pub
```

---

## 🔒 Security & Privacy Implementation

1. **No Plaintext Passwords:** Firebase Authentication securely hashes and stores credentials. Plaintext passwords are not stored in Firestore.
2. **Strict Document Ownership:** Database access is isolated per authenticated user (`users/${email}_${uid}/`).
3. **Write Verification:** The agent verifies that Firestore documents exist on disk before reporting success.
4. **Anti-Replay Protection:** Once a pending action is executed or cancelled, it cannot be re-executed.
5. **Tamper-Evident Audit Logs:** Audit logs are append-only. Rules prevent modification or deletion.

---

## 📂 Competition Deliverables

- 📘 [Technical Documentation](docs/TECHNICAL_DOCUMENTATION.md)
- 🛡️ [Security Self-Assessment Report](docs/SECURITY_ASSESSMENT.md)
- 📊 [Sanitized Execution Evidence](docs/EXECUTION_EVIDENCE.md)
- 🎙️ [10-Minute Presentation Outline](docs/PRESENTATION_OUTLINE.md)
- 🎬 [5-Minute Demo Video Script](docs/DEMO_SCRIPT.md)