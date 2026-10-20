/**
 * Pulse Expense Agent Deterministic Tools
 * Tier 1 (Read-only, auto-executed, plain JavaScript math)
 * Tier 2 (Proposals only, creates PENDING pending_action in Firestore)
 * 
 * Interacts with Firestore via FirestoreRestClient (User ID token)
 */

const { randomUUID } = require("crypto");
const { wrapUntrustedData, sanitizeString } = require("./guard");
const { validateToolCall } = require("./validate");

// Helper: Calculate month boundary dates
function getMonthRange(monthStr) {
  const now = new Date();
  const target = monthStr || `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
  const [yearStr, monthNumStr] = target.split("-");
  const y = parseInt(yearStr, 10);
  const m = parseInt(monthNumStr, 10);

  const nextM = m === 12 ? 1 : m + 1;
  const nextY = m === 12 ? y + 1 : y;

  const start = `${target}-01`;
  const end = `${nextY}-${String(nextM).padStart(2, "0")}-01`;

  return { targetMonth: target, start, end };
}

// =========================================================================
// TIER 1 PURE CALCULATION ENGINES (Exported for unit testing without DB)
// =========================================================================

function computeSummary(transactions, targetMonth) {
  let totalIncome = 0;
  let totalExpense = 0;
  const categoryBreakdown = {};

  for (const t of transactions) {
    const amt = Number(t.amount) || 0;
    const cat = t.category_name || t.categoryName || "Other";

    if (t.isIncome === true) {
      totalIncome += amt;
    } else {
      totalExpense += amt;
      categoryBreakdown[cat] = (categoryBreakdown[cat] || 0) + amt;
    }
  }

  const netSavings = totalIncome - totalExpense;
  const savingsRate = totalIncome > 0 ? (netSavings / totalIncome) * 100 : 0;

  return {
    month: targetMonth,
    currency: "৳",
    totalIncome: Number(totalIncome.toFixed(2)),
    totalExpense: Number(totalExpense.toFixed(2)),
    netSavings: Number(netSavings.toFixed(2)),
    savingsRate: Number(savingsRate.toFixed(2)),
    categoryBreakdown,
    transactionCount: transactions.length,
  };
}

function computeUnusualSpending(expenses) {
  // Group expenses by category
  const catGroups = {};
  for (const t of expenses) {
    if (t.isIncome === true) continue;
    const cat = t.category_name || t.categoryName || "Other";
    if (!catGroups[cat]) catGroups[cat] = [];
    catGroups[cat].push(t);
  }

  const anomalies = [];

  for (const [cat, items] of Object.entries(catGroups)) {
    // Only analyze categories with at least 3 samples to have a reliable mean
    if (items.length < 3) continue;

    const total = items.reduce((sum, item) => sum + (Number(item.amount) || 0), 0);
    const mean = total / items.length;

    for (const item of items) {
      const amt = Number(item.amount) || 0;
      // Anomaly rule: >= 1.5x category mean and >= 500 BDT (or $20)
      if (amt >= mean * 1.5 && amt >= 500) {
        anomalies.push({
          id: item.id || null,
          category: cat,
          amount: amt,
          categoryAverage: Number(mean.toFixed(2)),
          spikeRatio: Number((amt / mean).toFixed(2)),
          date: item.date || "",
          description: sanitizeString(item.description || "", 100),
        });
      }
    }
  }

  // Sort by highest spike ratio descending
  anomalies.sort((a, b) => b.spikeRatio - a.spikeRatio);
  return anomalies.slice(0, 10);
}

function computeRecurringBills(expenses) {
  // Group expenses by normalized description
  const groups = {};

  for (const t of expenses) {
    if (t.isIncome === true) continue;
    const rawDesc = (t.description || "").trim();
    if (!rawDesc) continue;

    // Normalize description: lowercase, strip dates/digits/special characters
    const normalized = rawDesc
      .toLowerCase()
      .replace(/[0-9]/g, "")
      .replace(/[^a-z\s]/g, "")
      .replace(/\s+/g, " ")
      .trim();

    if (normalized.length < 3) continue;

    if (!groups[normalized]) {
      groups[normalized] = {
        title: rawDesc,
        category: t.category_name || t.categoryName || "Bills & Utilities",
        items: [],
      };
    }
    groups[normalized].items.push(t);
  }

  const recurring = [];

  for (const [key, group] of Object.entries(groups)) {
    const items = group.items;
    // Distinct calendar months
    const monthsSet = new Set(items.map((i) => (i.date ? i.date.substring(0, 7) : "")));
    monthsSet.delete("");

    // Must occur in at least 2 distinct months
    if (monthsSet.size < 2) continue;

    const amounts = items.map((i) => Number(i.amount) || 0);
    const avgAmount = amounts.reduce((a, b) => a + b, 0) / amounts.length;

    // Determine typical day of month
    const days = items
      .map((i) => (i.date ? parseInt(i.date.substring(8, 10), 10) : null))
      .filter((d) => d !== null);
    const typicalDay = days.length > 0 ? Math.round(days.reduce((a, b) => a + b, 0) / days.length) : 1;

    // Calculate trend: % change between latest and previous
    items.sort((a, b) => (b.date || "").localeCompare(a.date || ""));
    const latestAmt = Number(items[0].amount) || 0;
    const prevAmt = items.length > 1 ? Number(items[1].amount) || latestAmt : latestAmt;
    const trendPct = prevAmt > 0 ? ((latestAmt - prevAmt) / prevAmt) * 100 : 0;

    // Project next expected date
    const now = new Date();
    const nextM = now.getMonth() + (now.getDate() > typicalDay ? 2 : 1);
    const nextY = now.getFullYear() + (nextM > 12 ? 1 : 0);
    const normalizedM = nextM > 12 ? nextM - 12 : nextM;
    const nextExpectedDate = `${nextY}-${String(normalizedM).padStart(2, "0")}-${String(typicalDay).padStart(2, "0")}`;

    recurring.push({
      title: group.title,
      category: group.category,
      avgAmount: Number(avgAmount.toFixed(2)),
      monthsCount: monthsSet.size,
      typicalDay,
      nextExpectedDate,
      trend: `${trendPct >= 0 ? "+" : ""}${trendPct.toFixed(1)}%`,
    });
  }

  return recurring;
}

function computeBudgetProposal(monthlyIncome, categoryAverages) {
  const income = Number(monthlyIncome) || 0;

  // 50/30/20 Rule targets
  const needsTarget = income * 0.5;
  const wantsTarget = income * 0.3;
  const savingsTarget = income * 0.2;

  const needsCategories = new Set([
    "Rent & Housing",
    "Housing",
    "Groceries",
    "Bills & Utilities",
    "Transportation",
    "Health & Medical",
    "Education",
  ]);

  const proposedBudgets = {};
  let calculatedNeedsTotal = 0;
  let calculatedWantsTotal = 0;

  for (const [cat, historicalAvg] of Object.entries(categoryAverages)) {
    const avg = Number(historicalAvg) || 0;
    if (avg <= 0) continue;

    // Recommended limit is slightly trimmed or smoothed historical average
    const suggestedLimit = Math.round(avg * 0.95);
    proposedBudgets[cat] = {
      historicalAverage: avg,
      suggestedLimit,
      type: needsCategories.has(cat) ? "Need" : "Want",
    };

    if (needsCategories.has(cat)) {
      calculatedNeedsTotal += suggestedLimit;
    } else {
      calculatedWantsTotal += suggestedLimit;
    }
  }

  return {
    referenceMonthlyIncome: income,
    ruleTargets: {
      needsLimit50: Number(needsTarget.toFixed(2)),
      wantsLimit30: Number(wantsTarget.toFixed(2)),
      savingsTarget20: Number(savingsTarget.toFixed(2)),
    },
    suggestedBudgets: proposedBudgets,
    projectedTotalExpense: calculatedNeedsTotal + calculatedWantsTotal,
    projectedSavings: Math.max(0, income - (calculatedNeedsTotal + calculatedWantsTotal)),
    advice: "Review the suggested limits. You can adopt any budget with 'create_budget' tool.",
  };
}

// =========================================================================
// FIRESTORE TOOL EXECUTORS (Uses FirestoreRestClient)
// =========================================================================

async function executeTier1Tool(client, docId, toolName, args = {}) {
  const validation = validateToolCall(toolName, args);
  if (!validation.valid) {
    throw new Error(validation.error);
  }

  const encodedUserDoc = encodeURIComponent(docId);

  switch (toolName) {
    case "get_summary": {
      const { targetMonth, start, end } = getMonthRange(args.month);
      const all = await client.listCollection(`users/${encodedUserDoc}/income_expenses`);
      const filtered = all.filter((t) => t.date && t.date >= start && t.date < end);
      return computeSummary(filtered, targetMonth);
    }

    case "get_transactions": {
      const all = await client.listCollection(`users/${encodedUserDoc}/income_expenses`);
      let list = all;

      if (args.month) {
        const { start, end } = getMonthRange(args.month);
        list = list.filter((t) => t.date && t.date >= start && t.date < end);
      }

      if (args.category) {
        const filterCat = args.category.toLowerCase().trim();
        list = list.filter(
          (t) => (t.category_name || t.categoryName || "").toLowerCase().trim() === filterCat
        );
      }

      list.sort((a, b) => (b.date || "").localeCompare(a.date || ""));

      const limit = Math.min(Number(args.limit) || 10, 50);
      return list.slice(0, limit).map((t) => ({
        id: t.id,
        amount: t.amount,
        isIncome: t.isIncome,
        category: t.category_name || t.categoryName || "Other",
        date: t.date,
        time: t.time || "",
        description: wrapUntrustedData(t.description || ""),
      }));
    }

    case "find_unusual_spending": {
      const all = await client.listCollection(`users/${encodedUserDoc}/income_expenses`);
      const expenses = all.filter((t) => t.isIncome !== true);
      return computeUnusualSpending(expenses);
    }

    case "detect_recurring_bills": {
      const all = await client.listCollection(`users/${encodedUserDoc}/income_expenses`);
      const expenses = all.filter((t) => t.isIncome !== true);
      return computeRecurringBills(expenses);
    }

    case "analyze_bill": {
      const all = await client.listCollection(`users/${encodedUserDoc}/income_expenses`);
      const searchTitle = (args.title || "").toLowerCase().trim();
      const matching = all
        .filter((t) => t.isIncome !== true)
        .filter((t) => (t.description || "").toLowerCase().includes(searchTitle));

      const monthly = {};
      for (const t of matching) {
        const m = (t.date || "").substring(0, 7);
        if (m) {
          monthly[m] = (monthly[m] || 0) + (Number(t.amount) || 0);
        }
      }

      const sortedMonths = Object.keys(monthly).sort();
      const history = [];

      for (let i = 0; i < sortedMonths.length; i++) {
        const m = sortedMonths[i];
        const amt = monthly[m];
        let changePct = "0.0%";
        if (i > 0) {
          const prev = monthly[sortedMonths[i - 1]];
          const diff = prev > 0 ? ((amt - prev) / prev) * 100 : 0;
          changePct = `${diff >= 0 ? "+" : ""}${diff.toFixed(1)}%`;
        }
        history.push({ month: m, amount: Number(amt.toFixed(2)), changePct });
      }

      return {
        query: args.title,
        history,
        totalTrackedOccurrences: matching.length,
      };
    }

    case "forecast_next_month": {
      const all = await client.listCollection(`users/${encodedUserDoc}/income_expenses`);
      const expenses = all.filter((t) => t.isIncome !== true);

      const monthCatMap = {};
      for (const t of expenses) {
        const m = (t.date || "").substring(0, 7);
        const cat = t.category_name || t.categoryName || "Other";
        if (!m) continue;
        if (!monthCatMap[m]) monthCatMap[m] = {};
        monthCatMap[m][cat] = (monthCatMap[m][cat] || 0) + (Number(t.amount) || 0);
      }

      const months = Object.keys(monthCatMap).sort().slice(-3); // Last 3 months
      const catTotals = {};

      for (const m of months) {
        for (const [cat, amt] of Object.entries(monthCatMap[m])) {
          catTotals[cat] = (catTotals[cat] || 0) + amt;
        }
      }

      const categoryForecasts = {};
      let totalForecast = 0;
      const numMonths = Math.max(months.length, 1);

      for (const [cat, sum] of Object.entries(catTotals)) {
        const avg = sum / numMonths;
        categoryForecasts[cat] = Number(avg.toFixed(2));
        totalForecast += avg;
      }

      const now = new Date();
      const nextMonthNum = now.getMonth() + 2;
      const nextMonthYear = now.getFullYear() + (nextMonthNum > 12 ? 1 : 0);
      const normalizedM = nextMonthNum > 12 ? nextMonthNum - 12 : nextMonthNum;
      const forecastedMonth = `${nextMonthYear}-${String(normalizedM).padStart(2, "0")}`;

      return {
        forecastedMonth,
        basedOnMonthsCount: months.length,
        categoryForecasts,
        totalForecast: Number(totalForecast.toFixed(2)),
      };
    }

    case "propose_budget": {
      const all = await client.listCollection(`users/${encodedUserDoc}/income_expenses`);
      const incomeMonths = {};
      const expenseMonths = {};

      for (const t of all) {
        const m = (t.date || "").substring(0, 7);
        if (!m) continue;
        const amt = Number(t.amount) || 0;
        if (t.isIncome === true) {
          incomeMonths[m] = (incomeMonths[m] || 0) + amt;
        } else {
          const cat = t.category_name || t.categoryName || "Other";
          if (!expenseMonths[cat]) expenseMonths[cat] = 0;
          expenseMonths[cat] += amt;
        }
      }

      const monthsCount = Math.max(Object.keys(incomeMonths).length, 1);
      const avgIncome = Object.values(incomeMonths).reduce((a, b) => a + b, 0) / monthsCount;

      const categoryAverages = {};
      for (const [cat, sum] of Object.entries(expenseMonths)) {
        categoryAverages[cat] = Number((sum / monthsCount).toFixed(2));
      }

      return computeBudgetProposal(avgIncome, categoryAverages);
    }

    case "get_budget_status": {
      const { targetMonth, start, end } = getMonthRange();

      const budgetsDocs = await client.listCollection(`users/${encodedUserDoc}/budgets`);
      const allExpenses = await client.listCollection(`users/${encodedUserDoc}/income_expenses`);

      const currentMonthExpenses = allExpenses.filter(
        (t) => t.isIncome !== true && t.date && t.date >= start && t.date < end
      );

      const spentMap = {};
      for (const t of currentMonthExpenses) {
        const cat = (t.category_name || t.categoryName || "Other").toLowerCase().replace(/\s+/g, "_");
        spentMap[cat] = (spentMap[cat] || 0) + (Number(t.amount) || 0);
      }

      const budgets = [];
      const alerts = [];
      let totalLimit = 0;
      let totalSpent = 0;

      for (const b of budgetsDocs) {
        const slug = b.id;
        const limit = Number(b.limit) || 0;
        const spent = spentMap[slug] || 0;
        const remaining = limit - spent;
        const percentage = limit > 0 ? (spent / limit) * 100 : 0;

        totalLimit += limit;
        totalSpent += spent;

        const isNearLimit = percentage >= 80 && percentage < 100;
        const isExceeded = percentage >= 100;

        budgets.push({
          category: b.category,
          limit,
          spent: Number(spent.toFixed(2)),
          remaining: Number(remaining.toFixed(2)),
          percentage: Number(percentage.toFixed(1)),
          isNearLimit,
          isExceeded,
        });

        if (isExceeded) {
          alerts.push(`🚨 Over budget for ${b.category}! Spent ৳${spent.toFixed(2)} of ৳${limit.toFixed(2)} (${percentage.toFixed(0)}%).`);
        } else if (isNearLimit) {
          alerts.push(`⚠️ ${b.category} spending is at ${percentage.toFixed(0)}% of monthly budget (৳${spent.toFixed(2)}/৳${limit.toFixed(2)}).`);
        }
      }

      return {
        month: targetMonth,
        budgets,
        totalLimit: Number(totalLimit.toFixed(2)),
        totalSpent: Number(totalSpent.toFixed(2)),
        alerts,
      };
    }

    default:
      throw new Error(`Unhandled tool: ${toolName}`);
  }
}

// =========================================================================
// TIER 2 PROPOSAL TOOLS (Creates PENDING action, never modifies budget/goal directly)
// =========================================================================

async function executeTier2Tool(client, uid, docId, toolName, args = {}) {
  const validation = validateToolCall(toolName, args);
  if (!validation.valid) {
    throw new Error(validation.error);
  }

  const actionId = randomUUID();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 15 * 60 * 1000); // 15 mins
  const encodedUserDoc = encodeURIComponent(docId);

  if (toolName === "create_budget") {
    const category = args.category.trim();
    const limit = Number(args.limit);
    const title = `Set Monthly Budget for ${category}: ৳${limit.toFixed(2)}`;

    const pendingAction = {
      id: actionId,
      uid,
      docId,
      actionType: "CREATE_BUDGET",
      title,
      parameters: { category, limit },
      status: "PENDING",
      createdAt: now,
      expiresAt,
    };

    await client.createDoc(
      `users/${encodedUserDoc}`,
      "pending_actions",
      actionId,
      pendingAction
    );

    return {
      status: "needs_confirmation",
      actionId,
      actionType: "CREATE_BUDGET",
      title,
      parameters: { category, limit },
      expiresAt: expiresAt.toISOString(),
    };
  }

  if (toolName === "create_savings_goal") {
    const goalName = args.goalName.trim();
    const targetAmount = Number(args.targetAmount);
    const targetMonths = Number(args.targetMonths);
    const monthlyRequired = targetAmount / targetMonths;
    const title = `Create Savings Goal '${goalName}': ৳${targetAmount.toFixed(2)} in ${targetMonths} months (৳${monthlyRequired.toFixed(2)}/mo)`;

    const pendingAction = {
      id: actionId,
      uid,
      docId,
      actionType: "CREATE_SAVINGS_GOAL",
      title,
      parameters: {
        goalName,
        targetAmount,
        targetMonths,
        monthlyRequired: Number(monthlyRequired.toFixed(2)),
      },
      status: "PENDING",
      createdAt: now,
      expiresAt,
    };

    await client.createDoc(
      `users/${encodedUserDoc}`,
      "pending_actions",
      actionId,
      pendingAction
    );

    return {
      status: "needs_confirmation",
      actionId,
      actionType: "CREATE_SAVINGS_GOAL",
      title,
      parameters: pendingAction.parameters,
      expiresAt: expiresAt.toISOString(),
    };
  }

  throw new Error(`Unsupported Tier 2 tool: ${toolName}`);
}

module.exports = {
  getMonthRange,
  computeSummary,
  computeUnusualSpending,
  computeRecurringBills,
  computeBudgetProposal,
  executeTier1Tool,
  executeTier2Tool,
};
