import { STRATEGY_MAP, ASSET_DISPLAY } from "../constants.js";

export function buildStrategyData(ordersByStrategy, deposit, allDates) {
  const assetCount = Object.keys(STRATEGY_MAP).length;
  const strategies = [];

  for (const [symbol, prefixes] of Object.entries(STRATEGY_MAP)) {
    const strategyCount = Object.keys(prefixes).length;
    const initialNav = deposit / assetCount / strategyCount;

    for (const [prefix, name] of Object.entries(prefixes)) {
      const key = `${symbol}_${prefix}`;
      const strategyOrders = ordersByStrategy.get(key);

      if (!strategyOrders || strategyOrders.totalTrades === 0) {
        strategies.push(buildEmptyStrategy(symbol, prefix, name, initialNav, allDates));
        continue;
      }

      let cumulativePnl = 0;
      const equityCurve = allDates.map((date) => {
        cumulativePnl += strategyOrders.dailyPnl.get(date) || 0;
        return {
          date,
          nav: Math.round((initialNav + cumulativePnl) * 100) / 100,
          performance: Math.round(cumulativePnl * 100) / 100,
        };
      });

      const totalPnl = strategyOrders.totalProfit - strategyOrders.totalLoss;

      strategies.push({
        symbol,
        asset_display: ASSET_DISPLAY[symbol] || symbol,
        prefix,
        name,
        initial_nav: Math.round(initialNav * 100) / 100,
        final_nav: Math.round((initialNav + totalPnl) * 100) / 100,
        performance: Math.round(totalPnl * 100) / 100,
        performance_pct:
          initialNav > 0
            ? Math.round((totalPnl / initialNav) * 100 * 100) / 100
            : 0,
        max_dd_pct: computeMaxDrawdownPct(equityCurve),
        total_trades: strategyOrders.totalTrades,
        wins: strategyOrders.wins,
        losses: strategyOrders.losses,
        win_rate: Math.round(strategyOrders.winRate * 100) / 100,
        profit_factor: Math.round(strategyOrders.profitFactor * 100) / 100,
        equity_curve: equityCurve,
      });
    }
  }

  strategies.sort((a, b) => b.performance_pct - a.performance_pct);
  return strategies;
}

function buildEmptyStrategy(symbol, prefix, name, initialNav, allDates) {
  const equityCurve = allDates.map((date) => ({
    date,
    nav: Math.round(initialNav * 100) / 100,
    performance: 0,
  }));

  return {
    symbol,
    asset_display: ASSET_DISPLAY[symbol] || symbol,
    prefix,
    name,
    initial_nav: Math.round(initialNav * 100) / 100,
    final_nav: Math.round(initialNav * 100) / 100,
    performance: 0,
    performance_pct: 0,
    max_dd_pct: 0,
    total_trades: 0,
    wins: 0,
    losses: 0,
    win_rate: 0,
    profit_factor: 0,
    equity_curve: equityCurve,
  };
}

function computeMaxDrawdownPct(equityCurve) {
  let peak = 0;
  let maxDrawdown = 0;

  for (const entry of equityCurve) {
    if (entry.nav > peak) peak = entry.nav;
    if (peak > 0) {
      const drawdown = ((peak - entry.nav) / peak) * 100;
      if (drawdown > maxDrawdown) maxDrawdown = drawdown;
    }
  }

  return Math.round(maxDrawdown * 100) / 100;
}
