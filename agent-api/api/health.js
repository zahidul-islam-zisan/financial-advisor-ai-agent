/**
 * Health Check Endpoint
 * GET /api/health
 */
const { handleCors } = require("../lib/auth");

module.exports = async function handler(req, res) {
  if (handleCors(req, res)) return;

  if (req.method !== "GET") {
    res.status(405).json({ error: "Method not allowed. Use GET." });
    return;
  }

  res.status(200).json({
    ok: true,
    service: "pulse-expense-agent-api",
    version: "1.0.0",
    timestamp: new Date().toISOString(),
  });
};
