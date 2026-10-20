/**
 * Authentication & CORS Middleware for Pulse Expense Vercel Serverless
 */
const { admin } = require("./db");

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

/**
 * Builds user root doc ID from decoded token: ${email}_${uid}
 */
function buildUserDocId(decodedToken) {
  const uid = decodedToken.uid || "";
  const email = (decodedToken.email || "").toLowerCase().trim();
  return `${email}_${uid}`;
}

/**
 * Verifies Bearer Firebase ID token from Authorization header.
 * Rejects with 401 if missing, malformed, or invalid.
 */
async function authenticateRequest(req, res) {
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
    const decodedToken = await admin.auth().verifyIdToken(token);
    const uid = decodedToken.uid;
    const email = (decodedToken.email || "").toLowerCase().trim();
    const docId = buildUserDocId(decodedToken);

    return {
      uid,
      email,
      docId,
    };
  } catch (err) {
    res.status(401).json({
      error: "Unauthorized: Invalid or expired Firebase ID token.",
    });
    return null;
  }
}

module.exports = {
  handleCors,
  buildUserDocId,
  authenticateRequest,
};
