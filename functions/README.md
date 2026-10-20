# Legacy Cloud Functions (Superseded)

> **Notice:** The contents of this directory (`functions/`) are **superseded** by the serverless agent architecture in [`agent-api/`](../agent-api/).

### Migration Context
- **Active Backend:** [`agent-api/`](../agent-api/) is deployed as a high-performance serverless Node.js backend on Vercel.
- **Why Superseded:** `functions/` originally used Google Cloud Functions with Firebase Admin SDK, requiring a Firebase Blaze (pay-as-you-go) billing plan. `agent-api/` was architected to authenticate Firebase ID tokens using Google's public JWKS (`jose`) and interact directly with Firestore REST endpoints on behalf of the authenticated user. This eliminates the Blaze plan requirement and centralizes AI agent execution in Vercel with zero client secrets.
- **Do Not Deploy:** Do not deploy `functions/` to Firebase. All active client requests route to `agent-api/` via `AgentService`.
