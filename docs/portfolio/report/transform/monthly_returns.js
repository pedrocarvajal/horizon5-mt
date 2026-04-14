export function buildMonthlyReturns(equityCurve) {
  const monthlyNav = new Map();
  for (const entry of equityCurve) {
    const yearMonth = entry.date.slice(0, 7);
    monthlyNav.set(yearMonth, entry.nav);
  }

  const monthsSorted = Array.from(monthlyNav.keys()).sort();
  const grid = {};

  for (let i = 1; i < monthsSorted.length; i++) {
    const yearMonth = monthsSorted[i];
    const previousYearMonth = monthsSorted[i - 1];
    const returnPct =
      ((monthlyNav.get(yearMonth) - monthlyNav.get(previousYearMonth)) /
        monthlyNav.get(previousYearMonth)) *
      100;

    const year = yearMonth.slice(0, 4);
    const month = parseInt(yearMonth.slice(5, 7), 10);

    if (!grid[year]) grid[year] = {};
    grid[year][month] = Math.round(returnPct * 100) / 100;
  }

  for (const year of Object.keys(grid)) {
    const yearMonths = monthsSorted
      .filter((ym) => ym.startsWith(year))
      .sort();

    if (yearMonths.length > 0) {
      const previousIndex = monthsSorted.indexOf(yearMonths[0]) - 1;
      const startNav =
        previousIndex >= 0
          ? monthlyNav.get(monthsSorted[previousIndex])
          : monthlyNav.get(yearMonths[0]);
      const endNav = monthlyNav.get(yearMonths[yearMonths.length - 1]);
      grid[year].total =
        Math.round(((endNav - startNav) / startNav) * 100 * 100) / 100;
    }
  }

  return grid;
}
