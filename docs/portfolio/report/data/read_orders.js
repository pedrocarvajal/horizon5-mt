import { readFileSync, readdirSync } from "node:fs";
import { join, basename } from "node:path";

function timestampToDate(timestamp) {
  return new Date(timestamp * 1000).toISOString().split("T")[0];
}

export function readOrders(seedDirectory) {
  const files = readdirSync(seedDirectory).filter(
    (file) =>
      file.endsWith("_Orders.json") &&
      !file.includes("_MARKET_") &&
      !file.includes("_GWY_"),
  );

  const ordersByStrategy = new Map();

  for (const file of files) {
    const parts = basename(file, "_Orders.json").split("_");
    const symbol = parts[0];
    const prefix = parts[1];
    const key = `${symbol}_${prefix}`;

    const raw = JSON.parse(readFileSync(join(seedDirectory, file), "utf-8"));
    const closedOrders = raw.filter((o) => o.profit_in_dollars !== 0);
    const stats = computeTradeStats(closedOrders);
    const dailyPnl = buildDailyPnl(closedOrders);

    ordersByStrategy.set(key, {
      symbol,
      prefix,
      orders: closedOrders,
      dailyPnl,
      ...stats,
    });
  }

  return ordersByStrategy;
}

function computeTradeStats(orders) {
  let totalTrades = 0;
  let wins = 0;
  let losses = 0;
  let totalProfit = 0;
  let totalLoss = 0;

  for (const order of orders) {
    totalTrades++;
    if (order.profit_in_dollars > 0) {
      wins++;
      totalProfit += order.profit_in_dollars;
    } else {
      losses++;
      totalLoss += Math.abs(order.profit_in_dollars);
    }
  }

  const winRate = totalTrades > 0 ? (wins / totalTrades) * 100 : 0;
  const profitFactor = totalLoss > 0 ? totalProfit / totalLoss : 0;

  return { totalTrades, wins, losses, totalProfit, totalLoss, winRate, profitFactor };
}

function buildDailyPnl(orders) {
  const dailyPnl = new Map();
  for (const order of orders) {
    const date = timestampToDate(order.close_time);
    dailyPnl.set(date, (dailyPnl.get(date) || 0) + order.profit_in_dollars);
  }
  return dailyPnl;
}
