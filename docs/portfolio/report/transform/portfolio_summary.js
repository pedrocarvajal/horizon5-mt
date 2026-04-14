import { STRATEGY_MAP } from "../constants.js";

export function buildPortfolioSummary(
  csvMetrics,
  equityCurve,
  deposit,
  maxDrawdownDuration,
) {
  const lastEntry = equityCurve[equityCurve.length - 1] || {};
  const firstDate = equityCurve[0]?.date || "";
  const lastDate = lastEntry.date || "";

  return {
    backtest_period: `${firstDate} to ${lastDate}`,
    initial_balance: deposit,
    final_balance: lastEntry.nav || 0,
    total_pnl: lastEntry.pnl || 0,
    total_return_pct: lastEntry.pct || 0,
    total_trades: parseInt(csvMetrics["Total Trades"] || "0", 10),
    profit_factor: parseFloat(csvMetrics["Profit Factor"] || "0"),
    sharpe_ratio: parseFloat(csvMetrics["Sharpe Ratio"] || "0"),
    recovery_factor: parseFloat(csvMetrics["Recovery Factor"] || "0"),
    max_dd_pct: csvMetrics["Equity Drawdown Relative"] || "",
    max_dd_abs: csvMetrics["Equity Drawdown Maximal"] || "",
    max_dd_duration: maxDrawdownDuration,
    win_rate: csvMetrics["Profit Trades (% of total)"] || "",
    avg_hold_time: csvMetrics["Average position holding time"] || "",
    lr_correlation: parseFloat(csvMetrics["LR Correlation"] || "0"),
    assets_count: Object.keys(STRATEGY_MAP).length,
    strategies_count: Object.values(STRATEGY_MAP).reduce(
      (sum, prefixes) => sum + Object.keys(prefixes).length,
      0,
    ),
  };
}
