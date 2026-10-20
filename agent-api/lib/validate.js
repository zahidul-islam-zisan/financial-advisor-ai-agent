/**
 * Tool Arguments & Allowlist Validator
 */

const ALLOWED_TOOLS = new Set([
  // Tier 1 (Read-only, auto-executed)
  "get_summary",
  "get_transactions",
  "find_unusual_spending",
  "detect_recurring_bills",
  "analyze_bill",
  "forecast_next_month",
  "propose_budget",
  "get_budget_status",

  // Tier 2 (Needs 2-step user confirmation)
  "create_budget",
  "create_savings_goal",
]);

const TIER_1_TOOLS = new Set([
  "get_summary",
  "get_transactions",
  "find_unusual_spending",
  "detect_recurring_bills",
  "analyze_bill",
  "forecast_next_month",
  "propose_budget",
  "get_budget_status",
]);

const TIER_2_TOOLS = new Set([
  "create_budget",
  "create_savings_goal",
]);

const MONTH_REGEX = /^\d{4}-(?:0[1-9]|1[0-2])$/;

function getToolTier(toolName) {
  if (TIER_1_TOOLS.has(toolName)) return 1;
  if (TIER_2_TOOLS.has(toolName)) return 2;
  return null;
}

function validateToolCall(toolName, args = {}) {
  if (!ALLOWED_TOOLS.has(toolName)) {
    return {
      valid: false,
      error: `Unknown or unauthorized tool: '${toolName}'. Tool not in allowlist.`,
    };
  }

  // Validate specific tool arguments
  switch (toolName) {
    case "get_summary":
    case "find_unusual_spending":
      if (args.month && !MONTH_REGEX.test(args.month)) {
        return { valid: false, error: "Invalid 'month' format. Must be YYYY-MM." };
      }
      break;

    case "get_transactions":
      if (args.month && !MONTH_REGEX.test(args.month)) {
        return { valid: false, error: "Invalid 'month' format. Must be YYYY-MM." };
      }
      if (args.limit !== undefined) {
        const lim = Number(args.limit);
        if (isNaN(lim) || lim < 1 || lim > 50) {
          return { valid: false, error: "'limit' must be an integer between 1 and 50." };
        }
      }
      if (args.category && (typeof args.category !== "string" || args.category.length > 100)) {
        return { valid: false, error: "'category' must be a string up to 100 characters." };
      }
      break;

    case "analyze_bill":
      if (!args.title || typeof args.title !== "string" || args.title.trim().length === 0 || args.title.length > 100) {
        return { valid: false, error: "'title' is required and must be between 1 and 100 characters." };
      }
      break;

    case "create_budget": {
      const { category, limit } = args;
      if (!category || typeof category !== "string" || category.trim().length === 0 || category.length > 100) {
        return { valid: false, error: "'category' must be a non-empty string up to 100 characters." };
      }
      const numLimit = Number(limit);
      if (isNaN(numLimit) || numLimit < 1 || numLimit > 10000000) {
        return { valid: false, error: "'limit' must be a positive number between 1 and 10,000,000." };
      }
      break;
    }

    case "create_savings_goal": {
      const { goalName, targetAmount, targetMonths } = args;
      if (!goalName || typeof goalName !== "string" || goalName.trim().length === 0 || goalName.length > 100) {
        return { valid: false, error: "'goalName' must be a non-empty string up to 100 characters." };
      }
      const numTarget = Number(targetAmount);
      if (isNaN(numTarget) || numTarget < 1 || numTarget > 100000000) {
        return { valid: false, error: "'targetAmount' must be a positive number between 1 and 100,000,000." };
      }
      const numMonths = Number(targetMonths);
      if (isNaN(numMonths) || !Number.isInteger(numMonths) || numMonths < 1 || numMonths > 120) {
        return { valid: false, error: "'targetMonths' must be an integer between 1 and 120." };
      }
      break;
    }

    default:
      // Other Tier 1 tools without mandatory arguments
      break;
  }

  return { valid: true };
}

module.exports = {
  ALLOWED_TOOLS,
  TIER_1_TOOLS,
  TIER_2_TOOLS,
  getToolTier,
  validateToolCall,
};
