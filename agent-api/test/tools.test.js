const { describe, it } = require("node:test");
const assert = require("node:assert");
const {
  computeSummary,
  computeUnusualSpending,
  computeRecurringBills,
  computeBudgetProposal,
} = require("../lib/tools");

describe("Deterministic Tool Engines Math & Logic", () => {
  it("computeSummary accurately calculates totals, net savings, and savings rate", () => {
    const mockTransactions = [
      { amount: 50000, isIncome: true, category_name: "Salary" },
      { amount: 15000, isIncome: false, category_name: "Rent & Housing" },
      { amount: 7000, isIncome: false, category_name: "Groceries" },
      { amount: 3000, isIncome: false, category_name: "Dining" },
    ];

    const summary = computeSummary(mockTransactions, "2026-10");

    assert.strictEqual(summary.totalIncome, 50000);
    assert.strictEqual(summary.totalExpense, 25000);
    assert.strictEqual(summary.netSavings, 25000);
    assert.strictEqual(summary.savingsRate, 50);
    assert.strictEqual(summary.categoryBreakdown["Rent & Housing"], 15000);
    assert.strictEqual(summary.categoryBreakdown["Groceries"], 7000);
    assert.strictEqual(summary.categoryBreakdown["Dining"], 3000);
    assert.strictEqual(summary.transactionCount, 4);
  });

  it("computeSummary handles zero income without NaN or division by zero", () => {
    const mockExpensesOnly = [
      { amount: 1200, isIncome: false, category_name: "Utilities" },
    ];

    const summary = computeSummary(mockExpensesOnly, "2026-10");

    assert.strictEqual(summary.totalIncome, 0);
    assert.strictEqual(summary.totalExpense, 1200);
    assert.strictEqual(summary.netSavings, -1200);
    assert.strictEqual(summary.savingsRate, 0);
    assert.strictEqual(Number.isFinite(summary.savingsRate), true);
  });

  it("computeUnusualSpending flags transactions >= 1.5x mean with >= 3 samples", () => {
    const expenses = [
      // Dining: 3 samples with average 1000
      { id: "1", amount: 1000, isIncome: false, category_name: "Dining", date: "2026-10-01", description: "Lunch" },
      { id: "2", amount: 1000, isIncome: false, category_name: "Dining", date: "2026-10-05", description: "Dinner" },
      { id: "3", amount: 1000, isIncome: false, category_name: "Dining", date: "2026-10-10", description: "Coffee" },
      // Spike transaction: 2500 (2.5x average)
      { id: "4", amount: 2500, isIncome: false, category_name: "Dining", date: "2026-10-15", description: "Steak dinner" },
      // Other category with only 1 sample -> must NOT be flagged as anomaly due to small sample
      { id: "5", amount: 9000, isIncome: false, category_name: "Shopping", date: "2026-10-18", description: "Jacket" },
    ];

    const anomalies = computeUnusualSpending(expenses);

    assert.strictEqual(anomalies.length, 1);
    assert.strictEqual(anomalies[0].category, "Dining");
    assert.strictEqual(anomalies[0].amount, 2500);
    assert.strictEqual(anomalies[0].categoryAverage, 1375); // (1000+1000+1000+2500)/4 = 1375, 2500 >= 1.5 * 1375 = 2062.5
    assert.strictEqual(anomalies[0].spikeRatio >= 1.5, true);
  });

  it("computeRecurringBills groups recurring charges across 2+ distinct months", () => {
    const expenses = [
      { amount: 1200, isIncome: false, category_name: "Bills & Utilities", date: "2026-08-10", description: "DESCO Electricity Bill" },
      { amount: 1250, isIncome: false, category_name: "Bills & Utilities", date: "2026-09-10", description: "DESCO Electricity Bill" },
      { amount: 1180, isIncome: false, category_name: "Bills & Utilities", date: "2026-10-10", description: "DESCO Electricity Bill" },
      // Single month expense -> must NOT be classified as recurring
      { amount: 3000, isIncome: false, category_name: "Shopping", date: "2026-10-05", description: "New Shoes" },
    ];

    const recurring = computeRecurringBills(expenses);

    assert.strictEqual(recurring.length, 1);
    assert.match(recurring[0].title, /Electricity/i);
    assert.strictEqual(recurring[0].monthsCount, 3);
    assert.strictEqual(recurring[0].typicalDay, 10);
    assert.strictEqual(typeof recurring[0].nextExpectedDate, "string");
  });

  it("computeBudgetProposal correctly computes 50/30/20 budget allocations", () => {
    const monthlyIncome = 60000;
    const categoryAverages = {
      "Rent & Housing": 20000,
      "Groceries": 10000,
      "Dining": 6000,
      "Entertainment": 4000,
    };

    const proposal = computeBudgetProposal(monthlyIncome, categoryAverages);

    assert.strictEqual(proposal.referenceMonthlyIncome, 60000);
    assert.strictEqual(proposal.ruleTargets.needsLimit50, 30000); // 50%
    assert.strictEqual(proposal.ruleTargets.wantsLimit30, 18000); // 30%
    assert.strictEqual(proposal.ruleTargets.savingsTarget20, 12000); // 20%

    assert.strictEqual(proposal.suggestedBudgets["Rent & Housing"].type, "Need");
    assert.strictEqual(proposal.suggestedBudgets["Dining"].type, "Want");
  });
});
