export function buildDrawdown(equityCurve) {
  let peak = 0;
  const dailyDrawdown = [];

  for (const entry of equityCurve) {
    if (entry.nav > peak) peak = entry.nav;
    const drawdownPct = peak > 0 ? ((peak - entry.nav) / peak) * 100 : 0;
    dailyDrawdown.push({
      date: entry.date,
      drawdown: Math.round(drawdownPct * 100) / 100,
    });
  }

  let maxDrawdownDuration = 0;
  let inDrawdown = false;
  let drawdownStartDate = "";
  peak = 0;

  for (const entry of equityCurve) {
    if (entry.nav >= peak) {
      if (inDrawdown) {
        const startDate = new Date(drawdownStartDate);
        const endDate = new Date(entry.date);
        const duration = Math.round(
          (endDate - startDate) / (1000 * 60 * 60 * 24),
        );
        if (duration > maxDrawdownDuration) maxDrawdownDuration = duration;
      }
      peak = entry.nav;
      inDrawdown = false;
    } else if (!inDrawdown) {
      drawdownStartDate = entry.date;
      inDrawdown = true;
    }
  }

  if (inDrawdown && equityCurve.length > 0) {
    const startDate = new Date(drawdownStartDate);
    const endDate = new Date(equityCurve[equityCurve.length - 1].date);
    const duration = Math.round(
      (endDate - startDate) / (1000 * 60 * 60 * 24),
    );
    if (duration > maxDrawdownDuration) maxDrawdownDuration = duration;
  }

  return { dailyDrawdown, maxDrawdownDuration };
}
