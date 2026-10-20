# 🎬 ExpensePulse — 5-Minute Video Demo Script

**Format:** Screen Recording + Voiceover  
**App Setup:** Flutter Web/Mobile running with demo user logged in and sample transactions pre-populated.

---

### [00:00 - 00:45] Scene 1: Introduction & Dashboard Overview
- **Visual:** Open ExpensePulse on the Dashboard screen. Show the dark-themed UI, monthly income/expense cards, and interactive category pie chart.
- **Voiceover:**  
  *"Welcome to ExpensePulse, an intelligent financial advisor app built with Flutter, Firebase, and Google Gemini. Managing finances shouldn't be about staring at static spreadsheets. Let's see how ExpensePulse turns raw transaction data into proactive, personalized insights."*

---

### [00:45 - 01:45] Scene 2: The Pulse AI Copilot
- **Visual:** Tap on the **AI Assistant** tab. The chat interface loads.
- **Voiceover:**  
  *"Tapping into the AI Assistant screen connects us to Pulse AI. Let's ask our first natural question:"*
- **Action:** Tap the suggestion chip: `📊 How am I spending my money?`
- **Visual:** AI thinks for a second, then responds with a structured breakdown: total income, total expense, savings rate, and category percentages.
- **Voiceover:**  
  *"Notice how fast and precise that was. Pulse AI doesn't hallucinate numbers. It triggers deterministic backend calculation tools that query our real Firestore transactions to compute exact balances and rates."*

---

### [01:45 - 02:45] Scene 3: Uncovering Anomalies (Deterministic Tools)
- **Action:** Type into chat: *"Did I have any unusual spending recently?"*
- **Visual:** AI responds:  
  `⚠️ Detected Unusual Spending Spikes:`  
  `• Dining on 2026-10-18: ৳2,800.00 (Amount is 2.3x higher than average Dining spending (৳1,200.00))`
- **Voiceover:**  
  *"Here, the agent triggered the `find_unusual_spending` tool. It automatically compared recent transactions against our historical category averages to flag an anomalous dinner spike."*

---

### [02:45 - 04:00] Scene 4: The 2-Step Confirmation & Immutable Audit Trail
- **Action:** Type: *"Please set a monthly budget for Dining at ৳4,000."*
- **Visual:** The AI does **NOT** write directly to the database. Instead, an interactive **Human Authorization Required** proposal card appears with `[Cancel]` and `[Confirm & Save]` buttons.
- **Voiceover:**  
  *"This is where ExpensePulse sets a new standard for fintech security. The AI cannot arbitrarily alter user financial records. It creates a temporary 15-minute pending proposal awaiting human approval."*
- **Action:** Tap `[Confirm & Save]`.
- **Visual:** The card instantly updates with a green checkmark `[✓ Action Confirmed & Executed]`, followed by:  
  `✅ Action Confirmed & Executed! Budget for 'Dining' set to ৳4,000.00/month. (Audit log entry created and verified in Firestore)`
- **Voiceover:**  
  *"Behind the scenes, our engine verified ownership, blocked replay attacks, wrote the verified record to Firestore, and recorded an immutable audit log entry."*

---

### [04:00 - 05:00] Scene 5: Security Architecture & Conclusion
- **Visual:** Quick switch to the Transactions and Menu screens, showing clean navigation, and then back to the home dashboard showing the newly active budget.
- **Voiceover:**  
  *"All user data is strictly isolated by authenticated UID, plaintext passwords have been eradicated, and all financial actions are tamper-evident. ExpensePulse brings together the reasoning power of Gemini with the deterministic rigor needed for modern fintech. Thank you!"*
