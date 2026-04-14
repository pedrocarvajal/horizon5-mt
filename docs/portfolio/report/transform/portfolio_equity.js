export function buildPortfolioEquity(ordersByStrategy, deposit) {
  const dailyPnl = new Map();

  for (const [, strategyOrders] of ordersByStrategy) {
    for (const [date, pnl] of strategyOrders.dailyPnl) {
      dailyPnl.set(date, (dailyPnl.get(date) || 0) + pnl);
    }
  }

  const allDates = generateDateRange(dailyPnl);

  let cumulativePnl = 0;
  const equityCurve = allDates.map((date) => {
    cumulativePnl += dailyPnl.get(date) || 0;
    const nav = deposit + cumulativePnl;
    const pct = deposit > 0 ? (cumulativePnl / deposit) * 100 : 0;
    return {
      date,
      nav: Math.round(nav * 100) / 100,
      pnl: Math.round(cumulativePnl * 100) / 100,
      pct: Math.round(pct * 100) / 100,
    };
  });

  return { equityCurve, initialBalance: deposit };
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
