import { STRATEGY_MAP, ASSET_DISPLAY } from "../constants.js";

export function buildAssetData(ordersByStrategy, deposit) {
  const assetCount = Object.keys(STRATEGY_MAP).length;
  const assets = {};

  for (const symbol of Object.keys(STRATEGY_MAP)) {
    const strategyCount = Object.keys(STRATEGY_MAP[symbol]).length;
    const initialNav = deposit / assetCount;

    const dailyPnl = new Map();
    for (const prefix of Object.keys(STRATEGY_MAP[symbol])) {
      const strategyOrders = ordersByStrategy.get(`${symbol}_${prefix}`);
      if (!strategyOrders) continue;
      for (const [date, pnl] of strategyOrders.dailyPnl) {
        dailyPnl.set(date, (dailyPnl.get(date) || 0) + pnl);
      }
    }

    const allDates = generateDateRange(dailyPnl);

    let cumulativePnl = 0;
    const equityCurve = allDates.map((date) => {
      cumulativePnl += dailyPnl.get(date) || 0;
      const nav = initialNav + cumulativePnl;
      const pct = initialNav > 0 ? (cumulativePnl / initialNav) * 100 : 0;
      return {
        date,
        nav: Math.round(nav * 100) / 100,
        pnl: Math.round(cumulativePnl * 100) / 100,
        pct: Math.round(pct * 100) / 100,
      };
    });

    let totalTrades = 0;
    let wins = 0;
    let totalProfit = 0;
    let totalLoss = 0;

    for (const prefix of Object.keys(STRATEGY_MAP[symbol])) {
      const stats = ordersByStrategy.get(`${symbol}_${prefix}`);
      if (!stats) continue;
      totalTrades += stats.totalTrades;
      wins += stats.wins;
      totalProfit += stats.totalProfit;
      totalLoss += stats.totalLoss;
    }

    const winRate = totalTrades > 0 ? (wins / totalTrades) * 100 : 0;
    const profitFactor = totalLoss > 0 ? totalProfit / totalLoss : 0;
    const lastEntry = equityCurve[equityCurve.length - 1] || {};

    assets[symbol] = {
      display_name: ASSET_DISPLAY[symbol] || symbol,
      strategy_count: strategyCount,
      initial_nav: Math.round(initialNav * 100) / 100,
      final_nav: lastEntry.nav || 0,
      total_pnl: lastEntry.pnl || 0,
      total_pct: lastEntry.pct || 0,
      total_trades: totalTrades,
      win_rate: Math.round(winRate * 100) / 100,
      profit_factor: Math.round(profitFactor * 100) / 100,
      equity_curve: equityCurve,
    };
  }

  return assets;
}

function generateDateRange(dailyPnl) {
  const dates = Array.from(dailyPnl.keys()).sort();
  if (dates.length === 0) return [];

  const result = [];
  const startDate = new Date(dates[0]);
  const endDate = new Date(dates[dates.length - 1]);

  for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
    result.push(d.toISOString().split("T")[0]);
  }

  return result;
}
