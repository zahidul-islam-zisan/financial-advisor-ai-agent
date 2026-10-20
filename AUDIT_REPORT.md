# 📋 Pulse Expense — Architecture, Security & Readiness Audit Report

> **Target:** Senior Flutter / Firebase Project Evaluation  
> **Topic:** Personal Finance Assistant (Smart Budgeting, Bill Analysis, Spending Insights, Actionable Recommendations)  
> **Target Integration:** Vercel Serverless API + Google Gemini Function Calling  
> **Audit Execution Date:** October 20, 2026  
> **Status:** READ-ONLY AUDIT COMPLETE

---

## 🚨 TOP 5 BLOCKERS / HIGH-PRIORITY ATTENTION ITEMS

1. **Non-Standard User Document ID Path Scheme (`users/{email}_{uid}`):**  
   Every collection in Firestore is nested under `users/{email}_{uid}` instead of the standard `users/{uid}`. Any external Vercel serverless agent verifying Firebase ID tokens will only receive `decodedToken.uid` and `decodedToken.email`. The serverless backend MUST explicitly reconstruct this exact composite path (`${email}_${uid}`) or all database reads/writes will fail with `NOT_FOUND` or `PERMISSION_DENIED`.
2. **Git Exposure Vulnerability (.gitignore gaps & `.git` not initialized):**  
   The project is **not yet a git repository** (`.git` NOT FOUND). Crucially, [.gitignore](file:///e:/financial_advisor_ai/expense_pulse-main/.gitignore) does **not** exclude `android/app/google-services.json`, `lib/firebase_options.dart`, or the release keystore [`key/pulse_expense.jks`](file:///e:/financial_advisor_ai/expense_pulse-main/key/pulse_expense.jks). Initializing git and pushing now would commit production credentials and keystores.
3. **Missing Recurring Bill & Subscription Data Model:**  
   The transaction schema (`income_expenses`) has no fields for bills, recurring status, due dates, or payment frequencies (`isRecurring`, `dueDate`, `billingCycle` are **NOT FOUND**). A Vercel/Gemini agent cannot perform deterministic bill analysis without either introducing a new `bills` collection or relying entirely on fragile text heuristics on `description`.
4. **Field Mapping Bug in `AddIncomeExpenseRequestModel`:**  
   `AddIncomeExpenseRequestModel.toJson()` writes `"category_id"` and `"category_name"`, but `fromJson()` reads `json['categoryId']` and `json['categoryName']`. Calling `fromJson()` on saved documents results in `null` category IDs. (`TransactionListResponseModel` uses `json['category_id']` correctly).
5. **No Existing Server-Side ID Token Verification Flow:**  
   The mobile client currently communicates directly with Firebase Auth, Cloud Firestore, and Google AI Studio via client SDKs. There is currently no `agent_service.dart` or HTTP interceptor passing `FirebaseAuth.instance.currentUser?.getIdToken()` to a Vercel serverless endpoint.

---

## 1. PROJECT OVERVIEW

### 1.1 SDK Versions & Dependencies

- **Dart SDK:** `^3.9.0` (as defined in [`pubspec.yaml`](file:///e:/financial_advisor_ai/expense_pulse-main/pubspec.yaml#L21-L22))
- **Flutter SDK:** Compatible with Flutter 3.x (tested against Flutter 3.41+ / Dart 3.11+)

#### Full Dependencies List ([`pubspec.yaml`](file:///e:/financial_advisor_ai/expense_pulse-main/pubspec.yaml#L30-L60))

| Package | Version Constraint | Type | Purpose in Codebase |
| :--- | :--- | :--- | :--- |
| `flutter` | `sdk: flutter` | Core | Flutter framework |
| `cupertino_icons` | `^1.0.8` | UI | iOS style icons |
| `firebase_core` | `^4.4.0` | Backend | Firebase app initialization |
| `firebase_auth` | `^6.1.4` | Auth | Email/password authentication |
| `cloud_firestore` | `^6.1.2` | Database | NoSQL document storage |
| `bloc` | `^9.2.0` | State | Core BLoC library |
| `flutter_bloc` | `^9.1.1` | State | Flutter widgets for BLoC |
| `dartz` | `^0.10.1` | Utility | Functional error handling (`Either<Failure, T>`) |
| `fl_chart` | `^1.1.1` | UI/Charts | Pie chart rendering on Dashboard |
| `intl` | `^0.20.2` | Formatting | Date/time and currency formatting |
| `url_launcher` | `^6.3.2` | Utility | Launch external links (tutorial video) |
| `hugeicons` | `^1.1.5` | UI | Icon pack used across menus and buttons |
| `in_app_update` | `^4.2.5` | Android | In-app update prompt service |
| `shimmer` | `^3.0.0` | UI | Loading skeletons |
| `http` | `^1.2.2` | Networking | REST HTTP client (used for Gemini / agent) |
| `flutter_test` | `sdk: flutter` | Dev | Automated unit and widget tests |
| `flutter_lints` | `^5.0.0` | Dev | Recommended linting rules |

### 1.2 Platforms Present

All six Flutter platform folders exist on disk:
- `android/` — Present (contains Gradle build scripts, namespace `com.rhProduction.pulse_expense`)
- `ios/` — Present (contains Runner Xcode project)
- `web/` — Present (contains `index.html`, `manifest.json`)
- `windows/` — Present (contains CMake and Windows runner)
- `macos/` — Present (contains macOS Runner project)
- `linux/` — Present (contains Linux CMake setup)

### 1.3 Folder Structure of `lib/` (3 Levels Deep)

```text
lib/
├── app/
│   ├── app_theme.dart
│   └── route/
│       ├── app_router.dart
│       └── app_routes.dart
├── core/
│   ├── constants/
│   │   ├── ai_config.dart
│   │   ├── app_assets.dart
│   │   ├── app_colors.dart
│   │   └── app_value.dart
│   ├── error/
│   │   ├── failure.dart
│   │   └── firebase_exception_handler.dart
│   ├── services/
│   │   └── update_service.dart
│   ├── utils/
│   │   └── date_time_utils.dart
│   └── widgets/
│       ├── app_error_message.dart
│       ├── custom_date_time_picker.dart
│       ├── custom_snackbar.dart
│       ├── custom_text_field.dart
│       └── mesh_background.dart
├── features/
│   ├── add_income_expense/
│   │   ├── data/
│   │   └── presentation/
│   ├── ai_assistant/
│   │   ├── data/
│   │   └── presentation/
│   ├── auth/
│   │   ├── data/
│   │   └── presentation/
│   ├── category/
│   │   ├── data/
│   │   └── presentation/
│   ├── dashboard/
│   │   ├── data/
│   │   └── presentation/
│   ├── menu/
│   │   └── presentation/
│   ├── root/
│   │   └── presentation/
│   ├── splash/
│   │   └── presentation/
│   └── transactions/
│       ├── data/
│       └── presentation/
├── firebase_options.dart
└── main.dart
```

### 1.4 State Management & Navigation Approach

- **State Management:** BLoC pattern using `flutter_bloc: ^9.1.1` and `bloc: ^9.2.0`.
  - Registered globally in [`lib/main.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/main.dart) via `MultiBlocProvider`:
    - `AuthBloc`
    - `AddIncomeExpenseBloc`
    - `TransactionBloc`
    - `CategoryBloc`
    - `DashboardBloc`
    - `AiAssistantBloc`
- **Navigation Approach:** Named route generator using Flutter's built-in `Navigator` with [`AppRouter.onGenerateRoute`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/app/route/app_router.dart) and string route constants defined in [`AppRoutes`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/app/route/app_routes.dart). Transitions use `MaterialPageRoute`. Bottom navigation in [`RootPage`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/root/presentation/pages/root_page.dart) manages top-level tab switching via local `_selectedIndex` state.

---

## 2. FIRESTORE DATA MODEL

### 2.1 Collection & Subcollection Paths Used in Code

| Collection / Subcollection Path | Accessing Code / Data Source | Primary Operation |
| :--- | :--- | :--- |
| `users/{email}_{uid}/profile/info` | [`AuthRemoteDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/auth/data/data_sources/auth_remote_data_source.dart#L35-L41) | Write on user registration |
| `users/{email}_{uid}/income_expenses/{docId}` | [`AddIncomeExpenseDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/add_income_expense/data/data_sources/add_income_expense_data_source.dart), [`TransactionRemoteDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/transactions/data/data_sources/transaction_remote_data_source.dart), [`DashboardRemoteDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/dashboard/data/data_sources/dashboard_remote_data_source.dart), [`AgentActionDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/data/data_sources/agent_action_data_source.dart) | Read, Create, Update, Delete |
| `users/{email}_{uid}/categories/{docId}` | [`CategoryRemoteDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/category/data/data_sources/category_remote_data_source.dart) | Read, Create (individual & batch default) |
| `users/{email}_{uid}/budgets/{categoryId}` | [`AgentActionDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/data/data_sources/agent_action_data_source.dart#L363-L374) | Read, Write (idempotent category slug) |
| `users/{email}_{uid}/savings_goals/{goalId}` | [`AgentActionDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/data/data_sources/agent_action_data_source.dart#L389-L404) | Read, Create |
| `users/{email}_{uid}/pending_actions/{actionId}` | [`AgentActionDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/data/data_sources/agent_action_data_source.dart#L235-L245) | Create proposals, Update confirmation |
| `users/{email}_{uid}/audit_logs/{logId}` | [`AgentActionDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/data/data_sources/agent_action_data_source.dart#L418-L435) | Create (Append-only audit trail) |
| `tutorial/video` | [`MenuPage`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/menu/presentation/pages/menu_page.dart#L34) | Read app guide video URL |

### 2.2 Detailed Document Schemas & Field Types

#### 1. `users/{email}_{uid}/profile/info`
- `uid`: `String` (Firebase Auth UID)
- `email`: `String` (User email address)
```json
{
  "uid": "usr_9481a_placeholder",
  "email": "user@example.com"
}
```

#### 2. `users/{email}_{uid}/income_expenses/{docId}` (Transactions)
- `amount`: `double` / `num` (Positive numeric monetary amount)
- `category_id`: `String` (Firestore document ID of category or empty)
- `category_name`: `String` (Human-readable category title, e.g. "Food & Dining")
- `date`: `String` (Date stored as **String** in `"YYYY-MM-DD"` format, e.g. `"2026-10-20"`)
- `time`: `String` (Time stored as **String**, e.g. `"10:30 AM"`)
- `description`: `String` (User-entered note)
- `isIncome`: `bool` (`true` for Income, `false` for Expense)
- `createdAt`: `Timestamp` (Firestore Server/Client Timestamp)
```json
{
  "amount": 250.00,
  "category_id": "cat_food_123",
  "category_name": "Food & Dining",
  "date": "2026-10-20",
  "time": "01:30 PM",
  "description": "Lunch with team",
  "isIncome": false,
  "createdAt": "2026-10-20T07:30:00Z"
}
```

#### 3. `users/{email}_{uid}/categories/{docId}`
- `name`: `String` (Category name)
- `createdAt`: `Timestamp`
```json
{
  "name": "Groceries",
  "createdAt": "2026-10-20T07:00:00Z"
}
```

#### 4. `users/{email}_{uid}/budgets/{categoryId}`
- `category`: `String` (Target category name)
- `limit`: `double` / `num` (Monthly spending cap)
- `createdAt`: `Timestamp`
- `updatedAt`: `Timestamp`
```json
{
  "category": "Dining",
  "limit": 4000.00,
  "createdAt": "2026-10-20T07:00:00Z",
  "updatedAt": "2026-10-20T07:00:00Z"
}
```

#### 5. `users/{email}_{uid}/savings_goals/{goalId}`
- `id`: `String` (Document ID)
- `goalName`: `String` (Goal title)
- `targetAmount`: `double` (Target savings amount)
- `targetMonths`: `int` (Duration in months)
- `monthlyContribution`: `double` (Calculated monthly requirement)
- `currentSaved`: `double` (Default `0.0`)
- `createdAt`: `Timestamp`
```json
{
  "id": "goal_7781",
  "goalName": "Emergency Fund",
  "targetAmount": 50000.00,
  "targetMonths": 10,
  "monthlyContribution": 5000.00,
  "currentSaved": 0.0,
  "createdAt": "2026-10-20T07:00:00Z"
}
```

#### 6. `users/{email}_{uid}/pending_actions/{actionId}`
- `id`: `String`
- `uid`: `String`
- `docId`: `String`
- `actionType`: `String` (`"CREATE_BUDGET"` or `"CREATE_SAVINGS_GOAL"`)
- `title`: `String` (Summary shown on confirmation card)
- `parameters`: `Map<String, dynamic>` (Exact arguments to execute)
- `status`: `String` (`"PENDING"`, `"CONFIRMED"`, `"REJECTED"`, or `"EXPIRED"`)
- `createdAt`: `Timestamp` / ISO String
- `expiresAt`: `Timestamp` / ISO String (15-minute validity window)
- `executedAt`: `Timestamp` (present if confirmed)
- `auditLogId`: `String` (present if confirmed)

#### 7. `users/{email}_{uid}/audit_logs/{logId}`
- `id`: `String`
- `uid`: `String`
- `docId`: `String`
- `actionId`: `String`
- `actionType`: `String`
- `status`: `String` (`"SUCCESS"`, `"FAILED"`, `"CANCELLED"`)
- `summary`: `String`
- `details`: `Map<String, dynamic>`
- `timestamp`: `Timestamp` / ISO String
- `verifiedByServer`: `bool`

#### 8. `tutorial/video`
- `video_link`: `String` (URL string, e.g. YouTube tutorial)

### 2.3 Category List: Hardcoded vs Stored

Categories are **both stored in Firestore and seeded from a hardcoded list**:
- Seed list located in [`CategoryRemoteDataSource.defaultCategoriesList`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/category/data/data_sources/category_remote_data_source.dart#L19-L32):
  1. `"Food & Dining"`
  2. `"Groceries"`
  3. `"Salary"`
  4. `"Freelance"`
  5. `"Rent & Housing"`
  6. `"Transportation"`
  7. `"Bills & Utilities"`
  8. `"Shopping"`
  9. `"Health & Medical"`
  10. `"Entertainment"`
  11. `"Investments"`
  12. `"Education"`
- When user taps "Add Default Categories" in [`CatagoryListPage`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/category/presentation/pages/catagory_list_page.dart), it batch-inserts missing entries into `users/{docId}/categories`. Users can also create custom categories with arbitrary names.

### 2.4 Currency Handling & Numeric Types

- **Currency Symbol:** Configured globally in [`AppValue.defaultCurrencySymbol = "৳"`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/core/constants/app_value.dart#L3) (Bangladeshi Taka default, supports USD `$`).
- **Data Type:** Stored as `double` / `num` across all models. No currency string or ISO code (e.g. `"BDT"`, `"USD"`) is persisted inside individual transaction records; the UI prefixes the symbol at display time.

### 2.5 Existing Budgets, Bills, Recurring, Wallets

| Feature | Base App State | Agent Extension State | Storage Location |
| :--- | :---: | :---: | :--- |
| **Budgets** | NOT FOUND | Added | `users/{email}_{uid}/budgets/{categoryId}` |
| **Recurring Bills / Subscriptions** | **NOT FOUND** | **NOT FOUND** | None |
| **Savings Goals** | NOT FOUND | Added | `users/{email}_{uid}/savings_goals/{goalId}` |
| **Multiple Wallets / Accounts** | **NOT FOUND** | **NOT FOUND** | None (Single account per user) |
| **Bill Reminders / Due Dates** | **NOT FOUND** | **NOT FOUND** | None |

### 2.6 Firestore Queries & Composite Index Requirements

1. **Transaction List:**
   ```dart
   collection("users").doc(docId).collection("income_expenses")
     .orderBy("createdAt", descending: true)
   ```
   *Index:* Uses Firestore single-field index on `createdAt` (Automatic).
2. **Monthly Dashboard Query:**
   ```dart
   collection("users").doc(docId).collection("income_expenses")
     .where("date", isGreaterThanOrEqualTo: startOfMonth)
     .where("date", isLessThan: lastOfMonth)
   ```
   *Index:* Uses Firestore single-field range index on `date` (Automatic).
3. **Category List:**
   ```dart
   collection("users").doc(docId).collection("categories")
     .orderBy("createdAt", descending: true)
   ```
   *Index:* Automatic.
4. **⚠️ Composite Index Risk for Agent:**
   If the Vercel agent or app combines a date filter with ordering, e.g.:
   `.where("date", isGreaterThanOrEqualTo: "...").orderBy("createdAt", descending: true)`  
   Firestore **will fail** unless a composite index on `income_expenses` (`date ASC, createdAt DESC`) is created in Firebase Console or `firestore.indexes.json`.

---

## 3. AUTHENTICATION

### 3.1 Implementation & Current User Identification
- Implemented via `firebase_auth: ^6.1.4` in [`AuthRemoteDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/auth/data/data_sources/auth_remote_data_source.dart).
- Supported methods: Email and Password (`createUserWithEmailAndPassword`, `signInWithEmailAndPassword`).
- **User UID retrieval:**
  `FirebaseAuth.instance.currentUser?.uid`
- **User Email retrieval:**
  `FirebaseAuth.instance.currentUser?.email`
- **Document ID generation:**
  `"${email}_${uid}"` (accessed across data sources as `get docId => "${email}_$uid"`).

### 3.2 Firebase ID Token Availability
- The code does not currently invoke `getIdToken()`, but because `FirebaseAuth.instance.currentUser` is present, fetching an ID token for the Vercel API is readily available:
  ```dart
  final String? idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
  ```
  This token can be sent as an `Authorization: Bearer <token>` header to the Vercel serverless function.

### 3.3 Profile Data Stored
- Stored at `users/{email}_{uid}/profile/info`:
  - `uid` (String)
  - `email` (String)
- **NOT FOUND in Profile:**
  - `name` / Full Name: **NOT FOUND**
  - `phone`: **NOT FOUND**
  - `currency`: **NOT FOUND**
  - `monthlyIncome`: **NOT FOUND**

---

## 4. FIRESTORE SECURITY RULES

### 4.1 Located Rules File: [`firestore.rules`](file:///e:/financial_advisor_ai/expense_pulse-main/firestore.rules)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper function: Check if caller is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }

    // Helper function: Check if user owns the document path
    // Supports existing legacy format "{email}_{uid}" and standard "{uid}"
    function isOwner(userDocId) {
      return isAuthenticated() && (
        userDocId == request.auth.token.email + '_' + request.auth.uid ||
        userDocId == request.auth.uid
      );
    }

    // User Root Document & Subcollections
    match /users/{userDocId} {
      allow read, write: if isOwner(userDocId);

      // User Profile Info
      match /profile/{profileDoc} {
        allow read: if isOwner(userDocId);
        // CRITICAL SECURITY CONTROL: Explicitly prohibit writing any password field to Firestore
        allow write: if isOwner(userDocId) && !('password' in request.resource.data);
      }

      // Categories
      match /categories/{categoryId} {
        allow read: if isOwner(userDocId);
        allow write: if isOwner(userDocId) 
          && request.resource.data.name is string 
          && request.resource.data.name.size() > 0 
          && request.resource.data.name.size() <= 100;
      }

      // Income & Expenses Transactions
      match /income_expenses/{transactionId} {
        allow read: if isOwner(userDocId);
        allow create, update: if isOwner(userDocId)
          && request.resource.data.amount is number
          && request.resource.data.amount > 0;
        allow delete: if isOwner(userDocId);
      }

      // Budgets (Phase 3 agent support)
      match /budgets/{budgetId} {
        allow read: if isOwner(userDocId);
        allow write: if isOwner(userDocId)
          && request.resource.data.limit is number
          && request.resource.data.limit > 0;
      }

      // Savings Goals (Phase 3 agent support)
      match /savings_goals/{goalId} {
        allow read: if isOwner(userDocId);
        allow write: if isOwner(userDocId)
          && request.resource.data.targetAmount is number
          && request.resource.data.targetAmount > 0;
      }

      // Pending Confirmation Actions (Phase 3 human confirmation workflow)
      match /pending_actions/{actionId} {
        allow read: if isOwner(userDocId);
        allow create: if isOwner(userDocId);
        allow update: if isOwner(userDocId)
          && request.resource.data.status in ['PENDING', 'CONFIRMED', 'REJECTED', 'EXPIRED'];
        allow delete: if isOwner(userDocId);
      }

      // Audit Logs: Append-only, tamper-proof audit trail
      match /audit_logs/{logId} {
        allow read: if isOwner(userDocId);
        allow create: if isOwner(userDocId);
        // Strictly prevent tampering or deletion of existing audit logs
        allow update, delete: if false;
      }
    }

    // Public / Shared Tutorial Video (Read-only for authenticated users)
    match /tutorial/{docId} {
      allow read: if isAuthenticated();
      allow write: if false;
    }

    // Default Deny: All other documents are strictly private and cross-user access is denied
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### 4.2 Security Evaluation & Risks

- **Cross-User Data Isolation:** Enforced via `isOwner(userDocId)`. Users can only read/write their own path.
- **Open Rules:** There are **NO** open public rules (`allow read, write: if true;` is NOT present).
- **Identified Risks:**
  1. **Production Deployment Gap:** While `firestore.rules` is present and tested via unit tests in the repo, it is **not yet deployed/published** to Firebase Console production.
  2. **Root User Document Write:** Line 21 (`match /users/{userDocId} { allow read, write: if isOwner(userDocId); }`) permits the user to write arbitrary fields to the top-level user document.
  3. **Vercel Serverless Integration:** When using a Vercel serverless function initialized with the Firebase Admin SDK (`firebase-admin`), rules are bypassed on the server. However, if the serverless function proxies requests using a user token via client REST, `request.auth.token.email` must match the path.

---

## 5. EXISTING BACKEND / AI / HTTP

### 5.1 Cloud Functions & AI Folders
- **`functions/` directory:** Present. Contains Firebase Cloud Functions setup ([`functions/index.js`](file:///e:/financial_advisor_ai/expense_pulse-main/functions/index.js), [`functions/package.json`](file:///e:/financial_advisor_ai/expense_pulse-main/functions/package.json)) with:
  - `agentChat`: Server-side proxy for Gemini 2.5 Flash using Google Secret Manager (`GEMINI_API_KEY`).
  - `confirmFinancialAction`: Server-side action validation and execution.
  - `cancelFinancialAction`: Server-side rejection.
  *(Note: Cloud Functions require Firebase Blaze plan and are not yet deployed).*
- **`lib/features/ai_assistant/`:** Fully implemented client-side AI feature:
  - [`AiRemoteDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/data/data_sources/ai_remote_data_source.dart): Makes direct HTTPS REST calls to `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent` using tool declarations (`get_summary`, `get_transactions`, `find_unusual_spending`, `create_budget`, `create_savings_goal`). Contains a deterministic offline rule engine fallback if no API key is provided.
  - [`AgentActionDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/data/data_sources/agent_action_data_source.dart): Handles tool calculations and 2-step confirmation proposals.
  - [`AiAssistantBloc`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart): Manages chat conversation state, tool calls, and confirmation card actions.

### 5.2 HTTP Packages & API Call Structure
- Package: `http: ^1.2.2`.
- `dio`: NOT FOUND.
- API structure: Direct `http.post` call with JSON body in `AiRemoteDataSource.sendMessage()`.

### 5.3 Configuration & Environment Files
- `.env`: **NOT FOUND** in root or `lib/`.
- [`lib/core/constants/ai_config.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/core/constants/ai_config.dart): Holds `defaultGeminiApiKey = ""`, `activeApiKey`, `modelName = "gemini-2.5-flash"`, and system instructions.
- [`lib/core/constants/app_colors.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/core/constants/app_colors.dart): Theme hex color constants.
- [`lib/core/constants/app_assets.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/core/constants/app_assets.dart): Asset icon strings.
- [`lib/core/constants/app_value.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/core/constants/app_value.dart): `appName` and `defaultCurrencySymbol`.

---

## 6. UI & FEATURES

### 6.1 Screen Inventory & Functionality

| Screen | File Path | Primary Functionality |
| :--- | :--- | :--- |
| **Splash** | [`splash_page.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/splash/presentation/pages/splash_page.dart) | Checks Firebase auth status; redirects to Login or Root |
| **Login** | [`login_page.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/auth/presentation/pages/login_page.dart) | Email/password login with input validation |
| **Register** | [`registion_page.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/auth/presentation/pages/registion_page.dart) | New user creation via Firebase Auth |
| **Root (Nav Container)** | [`root_page.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/root/presentation/pages/root_page.dart) | 4-tab Bottom Navigation bar managing screen index |
| **Dashboard** | [`dashboard_page.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/dashboard/presentation/pages/dashboard_page.dart) | Income/Expense balance cards, category PieChart, recent list, Filter dropdown ("Monthly" / "All") |
| **Transactions** | [`transactions_page.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/transactions/presentation/pages/transactions_page.dart) | Full scrollable transaction list, delete swipe/action, edit action |
| **Add / Edit Transaction** | [`add_income_expense_page.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/add_income_expense/presentation/pages/add_income_expense_page.dart) | Form to enter amount, date, time, category, note, Income/Expense toggle |
| **Category List** | [`catagory_list_page.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/category/presentation/pages/catagory_list_page.dart) | View user categories, create custom category, seed 12 defaults |
| **AI Assistant** | [`ai_assistant_page.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/presentation/pages/ai_assistant_page.dart) | Natural language chat interface, suggestion chips, interactive confirmation cards, API key dialog |
| **Menu** | [`menu_page.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/menu/presentation/pages/menu_page.dart) | User email display, navigation to Categories, tutorial video launcher, logout dialog |

### 6.2 Existing Dashboard, Charts & Calculation Logic
- **Calculation Logic:** [`DashboardBloc`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/dashboard/presentation/bloc/dashboard_bloc.dart#L24-L33) computes `totalIncome` and `totalExpense` by iterating over `transactionList`.
- **Chart Logic:** [`DashboardPage`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/dashboard/presentation/pages/dashboard_page.dart#L350-L410) builds `distribution` map by grouping `category_name` and calculating percentage shares for `fl_chart.PieChart`.
- **Agent Calculation Logic:** [`AgentActionDataSource`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/data/data_sources/agent_action_data_source.dart) deterministically computes monthly totals, net savings, savings rate, and unusual spending spikes ($\ge 1.5 \times \text{mean}$).

### 6.3 Chat Assistant Integration Location
- A **Chat Assistant is already integrated as Tab 2** in [`RootPage`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/root/presentation/pages/root_page.dart#L21) (`AiAssistantPage`).
- **File to edit to point to Vercel API:** [`lib/features/ai_assistant/data/data_sources/ai_remote_data_source.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/data/data_sources/ai_remote_data_source.dart) (replace Google AI Studio direct URL with your Vercel endpoint `https://your-vercel-app.vercel.app/api/agent`).

### 6.4 Theme, Localization & Reusable Widgets
- **Theme:** Dark theme with custom linear gradient background (`MeshBackground`), styled in [`lib/app/app_theme.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/app/app_theme.dart).
- **Localization:** **English only**. No localization packages configured (`intl` is used for date/number formatting only). Currency symbol defaults to `"৳"` (Bangladeshi Taka).
- **Reusable Core Widgets:**
  - [`MeshBackground`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/core/widgets/mesh_background.dart): Gradient screen wrapper
  - [`CustomTextField`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/core/widgets/custom_text_field.dart): Form inputs
  - [`CustomDateTimePicker`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/core/widgets/custom_date_time_picker.dart): Date/time selector
  - [`CustomSnackbar`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/core/widgets/custom_snackbar.dart): Alert notifications
  - [`TransactionCard`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/transactions/presentation/widgets/transaction_card.dart): Transaction item card
  - [`AiMessageBubble`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/presentation/widgets/ai_message_bubble.dart): Chat bubble with embedded confirmation card

---

## 7. REPO & SECURITY READINESS

### 7.1 Git Repository & `.gitignore` Assessment
- **Git Repo:** **NOT INITIALIZED** (`.git` directory NOT FOUND).
- **`.gitignore` Evaluation:** **CRITICALLY INADEQUATE**.
  The current `.gitignore` is standard Flutter boilerplate and is missing critical secret/credential rules.

### 7.2 Sensitive Files Audit & Exposure Risk

| File Path | Exists on Disk? | Present in `.gitignore`? | Risk Assessment |
| :--- | :---: | :---: | :--- |
| `android/app/google-services.json` | **YES** | **NO** | ⚠️ High: Firebase project client config exposed |
| `ios/Runner/GoogleService-Info.plist` | NO (NOT FOUND) | NO | N/A |
| `lib/firebase_options.dart` | **YES** | **NO** | ⚠️ High: Contains client API keys & project IDs |
| `key/pulse_expense.jks` | **YES** | **NO** | 🚨 Critical: Release keystore exposed to Git |
| `.env` / `.env.local` | NO (NOT FOUND) | **NO** | Any newly created `.env` will be tracked |
| `functions/node_modules/` | NO | **NO** | Root `.gitignore` does not ignore `functions/node_modules/` |
| Service Account JSON (`*service-account*.json`) | NO (NOT FOUND) | **NO** | Any downloaded service account key will be tracked |

### 7.3 Hardcoded Secrets in Code
- **Firebase Client API Keys (Public client keys):**
  - Hardcoded in [`lib/firebase_options.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/firebase_options.dart) on lines 44, 54, 62, 71, 80 (standard FlutterFire setup).
- **Keystores:**
  - Android release signing keystore on disk at [`key/pulse_expense.jks`](file:///e:/financial_advisor_ai/expense_pulse-main/key/pulse_expense.jks).
- **Gemini API Key:**
  - `AiConfig.defaultGeminiApiKey` in [`lib/core/constants/ai_config.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/core/constants/ai_config.dart#L7) is empty string `""` (no secret committed). User enters key at runtime in UI.

### 7.4 README & Test Suite Coverage
- **README:** Present at [`README.md`](file:///e:/financial_advisor_ai/expense_pulse-main/README.md) (Fintech competition documentation).
- **Test Suite:** **5 test files, 22 passing automated tests** in [`test/`](file:///e:/financial_advisor_ai/expense_pulse-main/test):
  1. [`agent_confirmation_flow_test.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/test/agent_confirmation_flow_test.dart) (6 tests: proposal creation, duplicate replay prevention, expiration rejection, cross-user denial, savings goal monthly rate, anomaly spike math).
  2. [`financial_calculation_test.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/test/financial_calculation_test.dart) (4 tests: balance arithmetic, division by zero protection, 50/30/20 budget allocations, string amount sanitization).
  3. [`firestore_rules_simulation_test.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/test/firestore_rules_simulation_test.dart) (8 tests: own-user access, plaintext password blocking, positive amounts, budget bounds, state transitions, audit log append-only enforcement, tutorial read-only, default deny).
  4. [`security_validation_test.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/test/security_validation_test.dart) (3 tests: RegistrationModel no plaintext password serialization, document ownership validation, prompt injection defense wrapping notes as data).
  5. [`widget_test.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/test/widget_test.dart) (1 test: smoke test for app branding and mesh background).

---

## 8. GAP ANALYSIS vs AI AGENT REQUIREMENTS

| Requirement | Status | Detailed Explanation |
| :--- | :---: | :--- |
| **Transaction Read Access for Agent** | **EXISTS** | [`AgentActionDataSource.getSummary()`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/data/data_sources/agent_action_data_source.dart#L30) and `getTransactions()` query `income_expenses` and return exact monthly totals, savings rate, and category breakdowns. |
| **Budget per Category + Alerts** | **PARTIAL** | Budgets can be created and stored in `users/{docId}/budgets/{categoryId}`, but there is **no alerting/notification system** (e.g. push notification when spending crosses 80% or 100% of budget cap). |
| **Recurring Bill Detection Data** | **MISSING** | Transactions have no `isRecurring`, `billingCycle`, or `dueDate` flags. Detecting recurring bills currently requires natural language parsing of descriptions. |
| **Savings Goals** | **PARTIAL** | Schema and creation tool exist in `users/{docId}/savings_goals`, but there is **no dedicated UI screen** to track goal progress or allocate savings. |
| **Anomaly Detection Inputs** | **PARTIAL** | Deterministic anomaly detection (`findUnusualSpending`) compares expenses to $1.5 \times \text{category average}$, but historical dataset is limited if user has fewer than 10 transactions. |
| **Audit Log Collection** | **EXISTS** | `users/{docId}/audit_logs` records all confirmed actions with timestamps and details. Append-only enforced in rules (`allow update, delete: if false`). |
| **Pending Actions / Confirmation Flow** | **EXISTS** | Proposal state machine with 15-minute expiry, ownership validation, and UI confirmation cards (`Confirm & Save` vs `Cancel`) in `AiMessageBubble`. |
| **Chat UI** | **EXISTS** | Complete chat interface in `AiAssistantPage` with suggestion chips, state management (`AiAssistantBloc`), and custom key configuration. |
| **Data Validation & Error Handling** | **PARTIAL** | Functional error handling (`dartz Either<Failure, T>`) and positive number checks exist, but model serialization contains `categoryId` key mismatch bug. |

---

## 9. RISKS & CONFLICTS

1. **Document ID Format Discrepancy (`${email}_${uid}`):**  
   If the Vercel serverless function uses `decodedToken.uid` as the document path, it will **not** find existing user transactions. The backend must always query `users/${decodedToken.email}_${decodedToken.uid}`.
2. **Date Format Inconsistency (String vs Timestamp):**  
   `income_expenses` documents store `date` as a plain String (`"2026-10-20"`), whereas `createdAt` is a `Timestamp`. All month-filtering logic relies on string comparison (`where("date", isGreaterThanOrEqualTo: "2026-10-01")`). If an agent creates a transaction with ISO string (`"2026-10-20T10:00:00Z"`) or a Timestamp, existing queries will fail.
3. **`category_id` vs `categoryId` Key Discrepancy:**  
   In `AddIncomeExpenseRequestModel`, `toJson()` writes `"category_id"`, but `fromJson()` expects `json['categoryId']`. When reading saved transactions via this model, `categoryId` returns `null`.
4. **Missing Composite Index for Complex Queries:**  
   Querying `.where("date", ...) .orderBy("createdAt", ...)` will cause a Firestore exception without a composite index. The Vercel agent must either order in-memory or a composite index must be created.
5. **Vercel Serverless Cold Start & Streaming:**  
   Flutter's `http` package waits for the entire JSON response. If Gemini takes 3-5 seconds to return function calls, the UI shows a loading bubble. Using SSE (Server-Sent Events) or streaming from Vercel provides a significantly smoother user experience.

---

## 10. RECOMMENDED INTEGRATION PLAN

### 10.1 Flutter App Changes

1. **Create [`lib/core/services/agent_service.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/core/services/agent_service.dart):**  
   Replace direct Gemini calls with a service calling your Vercel serverless endpoint:
   ```dart
   final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
   final response = await http.post(
     Uri.parse('https://your-vercel-agent.vercel.app/api/chat'),
     headers: {
       'Content-Type': 'application/json',
       'Authorization': 'Bearer $idToken',
     },
     body: jsonEncode({
       'message': userMessage,
       'history': history,
     }),
   );
   ```
2. **Update [`lib/features/ai_assistant/data/data_sources/ai_remote_data_source.dart`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/ai_assistant/data/data_sources/ai_remote_data_source.dart):**  
   Route `sendMessage` through `AgentService` so the client no longer needs any Gemini API key.
3. **Add Spending Insight Cards to Dashboard:**  
   In [`DashboardPage`](file:///e:/financial_advisor_ai/expense_pulse-main/lib/features/dashboard/presentation/pages/dashboard_page.dart), add an "AI Insights" banner widget displaying anomalous spending spikes or budget alerts generated by the agent.
4. **Update `.gitignore` Immediately:**  
   Add the following lines before initializing Git:
   ```gitignore
   android/app/google-services.json
   ios/Runner/GoogleService-Info.plist
   lib/firebase_options.dart
   key/
   *.jks
   *.keystore
   .env*
   functions/node_modules/
   ```

### 10.2 Recommended Firestore Schema Additions

To support bill tracking and proactive budgeting without breaking existing code:

#### New Subcollection: `users/{email}_{uid}/bills/{billId}`
```json
{
  "id": "bill_electric_01",
  "title": "Electricity Bill",
  "category": "Bills & Utilities",
  "expectedAmount": 1800.00,
  "dueDayOfMonth": 15,
  "frequency": "MONTHLY",
  "isAutoPay": false,
  "lastPaidDate": "2026-09-15",
  "createdAt": "2026-10-20T07:00:00Z"
}
```

#### New Subcollection: `users/{email}_{uid}/insights/{insightId}`
```json
{
  "id": "ins_9912",
  "type": "OVERSPENDING_WARNING",
  "category": "Food & Dining",
  "message": "You have spent 85% of your Dining budget with 10 days remaining.",
  "severity": "WARNING",
  "createdAt": "2026-10-20T07:00:00Z",
  "isDismissed": false
}
```

### 10.3 Required Firestore Security Rules Additions

Append these rules inside `match /users/{userDocId}` in [`firestore.rules`](file:///e:/financial_advisor_ai/expense_pulse-main/firestore.rules):

```javascript
// Bills & Subscriptions
match /bills/{billId} {
  allow read, write: if isOwner(userDocId)
    && request.resource.data.expectedAmount is number
    && request.resource.data.expectedAmount > 0;
  allow delete: if isOwner(userDocId);
}

// AI Spending Insights & Recommendations
match /insights/{insightId} {
  allow read: if isOwner(userDocId);
  allow create, update: if isOwner(userDocId);
  allow delete: if isOwner(userDocId);
}
```

---
*Report generated strictly from repository code analysis without altering source files.*
