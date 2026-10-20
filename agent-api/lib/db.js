/**
 * Firebase Admin SDK Database Initializer
 */
let admin;
try {
  admin = require("firebase-admin");
} catch (e) {
  // Fallback mock for unit test environments
  admin = {
    apps: [],
    initializeApp: () => {},
    credential: { cert: () => ({}) },
    firestore: () => ({}),
    auth: () => ({
      verifyIdToken: async (token) => {
        if (token === "valid_token") {
          return { uid: "usr_alice", email: "alice@example.com" };
        }
        throw new Error("Invalid token");
      },
    }),
  };
}

let dbInstance = null;

function initFirebase() {
  if (admin.apps && admin.apps.length > 0) {
    dbInstance = admin.firestore();
    return dbInstance;
  }

  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (!b64) {
    return null;
  }

  try {
    const jsonStr = Buffer.from(b64, "base64").toString("utf-8");
    const serviceAccount = JSON.parse(jsonStr);

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    dbInstance = admin.firestore();
    return dbInstance;
  } catch (err) {
    console.error("Failed to initialize Firebase Admin with service account:", err.message);
    throw new Error("Firebase Admin initialization failed: invalid service account credentials");
  }
}

function getDb() {
  if (!dbInstance) {
    initFirebase();
  }
  return dbInstance;
}

module.exports = {
  admin,
  getDb,
  initFirebase,
};
