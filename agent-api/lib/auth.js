/**
 * Authentication Middleware for Pulse Expense
 * Verifies Firebase ID Tokens locally using Google's JWKS and 'jose'
 * NO service account or firebase-admin required.
 */
const { jwtVerify, createRemoteJWKSet } = require("jose");

const GOOGLE_JWKS_URL = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
let defaultJWKS = null;

function getJWKS() {
  if (!defaultJWKS) {
    defaultJWKS = createRemoteJWKSet(new URL(GOOGLE_JWKS_URL));
  }
  return defaultJWKS;
}

function handleCors(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).end();
    return true;
  }
  return false;
}

function buildUserDocId(arg1, arg2) {
  let email, uid;
  if (typeof arg1 === "object" && arg1 !== null) {
    email = arg1.email;
    uid = arg1.uid;
  } else {
    email = arg1;
    uid = arg2;
  }
  const cleanEmail = (email || "").toLowerCase().trim();
  const cleanUid = (uid || "").trim();
  return `${cleanEmail}_${cleanUid}`;
}

/**
 * Verifies a Firebase ID token.
 * Can accept optional options for testing (e.g. custom key/JWKS, projectId).
 */
async function verifyFirebaseToken(token, options = {}) {
  const projectId = options.projectId || process.env.FIREBASE_PROJECT_ID || "pulse-expense-3156f";
  const jwks = options.jwks || getJWKS();

  const issuer = `https://securetoken.google.com/${projectId}`;
  const audience = projectId;

  const { payload, protectedHeader } = await jwtVerify(token, jwks, {
    issuer,
    audience,
    algorithms: ["RS256"],
  });

  // Verify alg is RS256
  if (protectedHeader.alg !== "RS256") {
    throw new Error("Invalid token algorithm: expected RS256.");
  }

  // Verify sub (UID) is non-empty
  const uid = payload.sub || payload.user_id;
  if (!uid || typeof uid !== "string" || uid.trim().length === 0) {
    throw new Error("Invalid token: empty subject.");
  }

  // Require email claim
  const email = payload.email;
  if (!email || typeof email !== "string" || email.trim().length === 0) {
    throw new Error("Invalid token: email claim is required.");
  }

  // Verify auth_time is in the past
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (payload.auth_time && payload.auth_time > nowSeconds + 60) {
    throw new Error("Invalid token: auth_time is in the future.");
  }

  const docId = buildUserDocId(email, uid);

  return {
    uid,
    email: email.toLowerCase().trim(),
    docId,
    idToken: token,
  };
}

/**
 * Authenticates an HTTP request using Bearer ID token.
 * Sends 401 on failure and returns null.
 */
async function authenticateRequest(req, res, options = {}) {
  const authHeader = req.headers.authorization || req.headers.Authorization || "";
  if (!authHeader.startsWith("Bearer ")) {
    res.status(401).json({
      error: "Unauthorized: Missing or malformed Bearer authorization token.",
    });
    return null;
  }

  const token = authHeader.substring(7).trim();
  if (!token) {
    res.status(401).json({
      error: "Unauthorized: Empty Bearer token provided.",
    });
    return null;
  }

  try {
    const verified = await verifyFirebaseToken(token, options);
    return verified;
  } catch (err) {
    res.status(401).json({
      error: "Unauthorized: Invalid, expired, or unverified Firebase ID token.",
    });
    return null;
  }
}

module.exports = {
  handleCors,
  buildUserDocId,
  verifyFirebaseToken,
  authenticateRequest,
};
