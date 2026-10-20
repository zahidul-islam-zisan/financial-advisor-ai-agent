# 🎙️ ExpensePulse — 10-Minute Competition Presentation Outline

---

## ⏱️ Timing & Slide Structure

| Slide / Section | Duration | Topic & Key Talking Points |
| :---: | :---: | :--- |
| **1. Hook & Problem** | 1:30 | **The Personal Finance Dilemma:** Users abandon manual budgeting apps because they lack insight; yet users distrust black-box AI advisors with automated bank/wallet actions. |
| **2. Solution Overview** | 1:30 | **Introducing ExpensePulse:** An intelligent Flutter + Firebase personal finance companion powered by Google Gemini 2.5 Flash with deterministic computation and human-in-the-loop control. |
| **3. Architecture & Tech** | 1:30 | **Feature-First Clean Architecture:** BLoC state management, Firestore security boundaries, deterministic tool execution, and Gemini function calling. |
| **4. Security Engineering** | 2:00 | **Zero-Trust Financial Design:**<br>• Plaintext passwords eliminated.<br>• Cross-user isolation enforced at DB rules level.<br>• Prompt injection containment (untrusted note isolation). |
| **5. Live Demo** | 2:30 | **The Agent in Action:**<br>• Step 1: Real-time query ("How am I spending my money?").<br>• Step 2: Anomaly Detection ("Any unusual spending?").<br>• Step 3: 2-Step Confirmation Flow ("Set Dining budget to ৳4,000" -> Proposal Card -> Human Confirms -> Verified Write -> Immutable Audit Log). |
| **6. Q&A & Future Roadmap** | 1:00 | **Next Horizons:** Open Banking API integrations, automated bill reminders, and multi-currency portfolio management. |

---

## 🎯 Speaker Key Notes & Emphases
- Emphasize that **math is never outsourced to the LLM**; all numbers are calculated by deterministic code.
- Emphasize the **2-Step Human Confirmation Workflow** as the core reason judges and regulators can trust this fintech application.
