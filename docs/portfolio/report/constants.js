export const STRATEGY_MAP = {
  XAUUSD: {
    BLR: "Ballarat",
    BDG: "Bendigo",
    CNS: "Cairns",
    DRW: "Darwin",
    GEL: "Geelong",
    HBT: "Hobart",
    MKY: "Mackay",
    TMW: "Tamworth",
    TWB: "Toowoomba",
    WLG: "Wollongong",
  },
  SP500: {
    AUS: "Austin",
    CHL: "Charlotte",
    DNV: "Denver",
    MEM: "Memphis",
    NSH: "Nashville",
    PHX: "Phoenix",
    PRT: "Portland",
    RLG: "Raleigh",
    TCS: "Tucson",
    TMP: "Tampa",
  },
  Nikkei225: {
    FKO: "Fukuoka",
    KBE: "Kobe",
    KYT: "Kyoto",
    NGT: "Niigata",
    NGY: "Nagoya",
    NKO: "Nikko",
    NRA: "Nara",
    OSK: "Osaka",
    SPR: "Sapporo",
    YKH: "Yokohama",
  },
};

export const ASSET_DISPLAY = {
  XAUUSD: "Gold",
  SP500: "S&P 500",
  Nikkei225: "Nikkei 225",
};

export const ASSET_COLORS = {
  XAUUSD: "#d4a017",
  SP500: "#2563eb",
  Nikkei225: "#dc2626",
};

export const COLORS = {
  positive: "#16a34a",
  negative: "#dc2626",
  black: "#000000",
  gray: "#666666",
  lightGray: "#999999",
  grid: "#e5e5e5",
  edge: "#cccccc",
  headerBackground: "#f0f0f0",
};

export const DRAWDOWN_THRESHOLDS = {
  green: { max: 5, color: "#16a34a" },
  yellow: { max: 10, color: "#ca8a04" },
  red: { max: Infinity, color: "#dc2626" },
};

export const STRATEGY_PALETTE = [
  "#e6194b", "#3cb44b", "#4363d8", "#f58231", "#911eb4",
  "#42d4f4", "#f032e6", "#bfef45", "#fabed4", "#469990",
  "#dcbeff", "#9A6324", "#800000", "#aaffc3", "#808000",
  "#000075", "#a9a9a9", "#e6beff", "#ffe119", "#ffd8b1",
  "#000000", "#fabebe", "#7eb0d5", "#b2e061", "#bd7ebe",
  "#ffb55a", "#beb9db", "#fdcce5", "#8bd3c7", "#d7191c",
];

export const LAYOUT = {
  pageWidthPx: 1123,
  pagePaddingPx: 40,
  sectionGapPx: 32,
  blockGapPx: 16,
  tableCellPaddingPx: 6,
  tableBorderPx: 1,
  fontSizeBodyPx: 11,
  fontSizeSmallPx: 11,
  fontSizeTitlePx: 16,
  fontSizeHeadingPx: 18,
  fontSizeLogoPx: 24,
  fontSizeChartAxisPx: 11,
  fontSizeChartLegendPx: 9,
  chartWidthPx: 1043,
  chartHeightPx: 600,
  chartHeightSmallPx: 180,
  chartHeightLargePx: 350,
  logoSizePx: 56,
};

export function buildIntroText(summary, monthlyReturns) {
  const backtestStart = summary.backtest_period.split(" to ")[0].slice(0, 4);
  const backtestEnd = summary.backtest_period.split(" to ")[1].slice(0, 4);
  const returnPct = summary.total_return_pct.toFixed(1);
  const sharpe = summary.sharpe_ratio.toFixed(2);
  const maxDdClean = summary.max_dd_pct.includes("(")
    ? summary.max_dd_pct.split("(")[0].trim()
    : summary.max_dd_pct;
  const recoveryFactor = summary.recovery_factor.toFixed(2);
  const lrCorrelation = summary.lr_correlation.toFixed(2);
  const winRateClean = summary.win_rate.includes("(")
    ? summary.win_rate.split("(")[1].replace(")", "").trim()
    : summary.win_rate;
  const maxDdDuration = summary.max_dd_duration;

  const worstYear = Object.entries(monthlyReturns)
    .filter(([, data]) => data.total !== undefined)
    .sort(([, a], [, b]) => a.total - b.total)[0];
  const worstYearNote =
    worstYear && worstYear[1].total > 0
      ? `Notably, the portfolio was profitable in ${worstYear[0]} (+${worstYear[1].total.toFixed(2)}%) while most markets declined.`
      : "";

  return [
    `Horizon5 is a fully automated, long-only algorithmic portfolio that trades Gold, S&P 500, and Nikkei 225 with ${summary.strategies_count} independent strategies. Each strategy uses technical indicators on the H1 timeframe to identify breakout entries, with ATR-scaled stop-losses and take-profits that enforce a consistent 2:1 reward-to-risk ratio on every trade.`,
    "Capital is allocated equally across assets and strategies -- no optimization, no prediction of which will outperform. The edge comes from diversification across uncorrelated markets and disciplined risk management: each trade risks a fixed percentage of equity, position sizes adapt to volatility, and no single strategy can drag down the portfolio.",
    `Over a ${parseInt(backtestEnd) - parseInt(backtestStart)}-year backtest (${backtestStart}-${backtestEnd}), the portfolio returned ${returnPct}% with a Sharpe ratio of ${sharpe}, a maximum drawdown of just ${maxDdClean}, and a recovery factor of ${recoveryFactor}. The equity curve has a ${lrCorrelation} linear regression correlation, meaning gains are consistent and predictable, not driven by a few lucky trades. ${worstYearNote}`,
    `The portfolio wins only ${winRateClean} of its trades -- but the average winner is significantly larger than the average loser. This asymmetry is by design: tight stops cut losses quickly, while wider take-profits let winning trades capture the full move. The result is a system that can lose more often than it wins and still compound capital reliably.`,
    `Where it can struggle: strong, sustained directional trends can produce short-term drawdowns as breakout entries get stopped out before reversals materialize. The longest drawdown period lasted ${maxDdDuration} days. These periods are expected and factored into the portfolio design -- the ${recoveryFactor} recovery factor means the system has historically earned nearly ${Math.floor(parseFloat(recoveryFactor))}x its worst drawdown in total profit.`,
  ];
}

export const PAPER_TRADING_URL = "https://www.myfxbook.com/portfolio/horizon5-01/11994293";
