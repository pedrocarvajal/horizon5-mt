import { readFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { LAYOUT } from "../constants.js";
import { renderHeader } from "./sections/header.js";
import { renderMonthlyReturnsTable } from "./sections/monthly_returns_table.js";
import { renderPortfolioSummaryTable } from "./sections/portfolio_summary_table.js";
import { renderAssetSummaryTables } from "./sections/asset_summary_tables.js";
import { renderStrategyRankingTable } from "./sections/strategy_ranking_table.js";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));

export function buildHtml({
  summary,
  monthlyReturns,
  assetData,
  maxDrawdownDuration,
  portfolioVsMarketSvg,
  drawdownSvg,
  assetEquitySvg,
  strategyEquityChart,
  strategyData,
  introText,
}) {
  const PORTFOLIO_DIR = join(SCRIPT_DIR, "..", "..");
  const backgroundPath = join(PORTFOLIO_DIR, "5bceecec-52f2-4232-9507-d0ba743ce02c.jpg");
  const backgroundBase64 = readFileSync(backgroundPath).toString("base64");
  const backgroundDataUri = `data:image/jpeg;base64,${backgroundBase64}`;

  const tailwindPath = join(SCRIPT_DIR, "tailwind.css");
  const tailwindCss = existsSync(tailwindPath)
    ? readFileSync(tailwindPath, "utf-8")
    : "";

  const headerHtml = renderHeader(introText);
  const monthlyReturnsHtml = renderMonthlyReturnsTable(monthlyReturns);
  const portfolioSummaryHtml = renderPortfolioSummaryTable(
    summary,
    maxDrawdownDuration,
  );
  const assetSummaryHtml = renderAssetSummaryTables(assetData);
  const strategyRankingHtml = renderStrategyRankingTable(strategyData);

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <style>${tailwindCss}</style>
  <style>
    @page { margin: 0; }
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: ${LAYOUT.fontSizeBodyPx}px;
      line-height: 1.5;
      color: #111827;
      background: #fff;
      background-image: url("${backgroundDataUri}");
      background-repeat: no-repeat;
      background-position: center bottom -500px;
      background-size: 100% auto;
      width: ${LAYOUT.pageWidthPx}px;
      padding: ${LAYOUT.pagePaddingPx}px ${LAYOUT.pagePaddingPx}px 250px ${LAYOUT.pagePaddingPx}px;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }
    .section { margin-bottom: ${LAYOUT.sectionGapPx}px; }
    .block { margin-bottom: ${LAYOUT.blockGapPx}px; }
    table { border-spacing: 0; border-collapse: collapse; width: 100%; }
    th, td {
      padding: ${LAYOUT.tableCellPaddingPx}px;
      border: ${LAYOUT.tableBorderPx}px solid #d1d5db;
      font-size: ${LAYOUT.fontSizeSmallPx}px;
    }
    th {
      background: #f3f4f6;
      font-weight: 700;
      font-size: ${LAYOUT.fontSizeSmallPx}px;
    }
    h2 {
      font-size: ${LAYOUT.fontSizeTitlePx}px;
      font-weight: 700;
      margin-bottom: ${LAYOUT.blockGapPx / 2}px;
    }
    h3 {
      font-size: ${LAYOUT.fontSizeBodyPx}px;
      font-weight: 700;
      margin-bottom: ${LAYOUT.blockGapPx / 2}px;
    }
    .mono { font-family: "SF Mono", "Menlo", "Monaco", "Consolas", "Liberation Mono", "Courier New", monospace; }
    .chart-container svg { width: 100%; height: auto; }
  </style>
</head>
<body>

  ${headerHtml}

  <div class="section">
    <h2>Portfolio vs Market (% Return)</h2>
    <div class="chart-container">${portfolioVsMarketSvg}</div>
  </div>

  <div class="section">
    <h2>Portfolio Drawdown</h2>
    <div class="chart-container">${drawdownSvg}</div>
  </div>

  <div class="section">
    ${monthlyReturnsHtml}
  </div>

  <div class="section">
    ${portfolioSummaryHtml}
  </div>

  <div class="section">
    <h2>Asset Equity Curves (% Return)</h2>
    <div class="chart-container">${assetEquitySvg}</div>
  </div>

  <div class="section">
    ${assetSummaryHtml}
  </div>

  <div class="section">
    <h2>Why This Works</h2>
    <p style="color: #6b7280; font-size: ${LAYOUT.fontSizeSmallPx}px; line-height: 1.6;">
      Gold, the S&P 500, and the Nikkei 225 share one structural trait: they tend to rise over time. Gold is driven by inflation hedging and central bank demand; U.S. and Japanese equities are driven by corporate earnings growth and monetary expansion. A long-only portfolio on these assets is not betting on direction -- it is harvesting the compounding effect of assets that have a positive expected return over decades. The 30 strategies do not try to predict the market; they systematically enter on short-term breakouts, manage risk with ATR-scaled stops, and let the underlying upward drift do the heavy lifting. When markets trend up, the strategies capture it. When markets pull back, tight stop-losses limit damage to single-digit drawdowns. The result is a portfolio where time is the primary edge: the longer it runs, the more the structural bias compounds, and the more short-term noise averages out. Diversification across three uncorrelated assets ensures that no single bad month in one market can derail the whole portfolio -- while one strong market can carry the returns.
    </p>
  </div>

  <div class="section">
    <h2>Strategy Equity Curves (% Return)</h2>
    ${strategyEquityChart.legendHtml}
    <div class="chart-container">${strategyEquityChart.svgChart}</div>
  </div>

  <div class="section">
    ${strategyRankingHtml}
  </div>

  <div class="section">
    <h2>Roadmap</h2>
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: ${LAYOUT.sectionGapPx}px; color: #6b7280; font-size: ${LAYOUT.fontSizeSmallPx}px; line-height: 1.6;">
      <div>
        <p style="margin-bottom: ${LAYOUT.blockGapPx / 2}px;">
          <strong style="color: #111827;">Expanded diversification:</strong> The current portfolio trades 3 assets with a long-only, trend-following edge suited to instruments with structural long-term growth. The next phase adds 2 additional indices to reach 5 assets and 50 strategies, reducing concentration risk and smoothing returns across a broader set of uncorrelated markets.
        </p>
        <p>
          <strong style="color: #111827;">Dynamic portfolio management:</strong> Not all strategies perform equally in every market regime. We are developing a dynamic allocation layer that activates and deactivates strategies based on real-time performance and correlation metrics, avoiding unnecessary overexposure and allocating capital where the edge is strongest at any given time.
        </p>
      </div>
      <div>
        <p>
          <strong style="color: #111827;">LLM-powered regime detection:</strong> The portfolio's main vulnerability is periods of extreme volatility or geopolitical uncertainty -- events like trade wars, armed conflicts, or sudden policy shifts that invalidate technical signals. To address this, we are building autonomous LLM agents that continuously analyze macroeconomic data, news flow, and sentiment indicators to detect regime shifts and reduce exposure before drawdowns materialize.
        </p>
      </div>
    </div>
  </div>

  <div style="margin-top: ${LAYOUT.sectionGapPx}px; padding-top: ${LAYOUT.blockGapPx}px; border-top: ${LAYOUT.tableBorderPx}px solid #d1d5db;">
    <p style="font-size: ${LAYOUT.fontSizeSmallPx}px; color: #9ca3af; line-height: 1.6;">
      <strong>Disclaimer:</strong> Past performance is not indicative of future results. The backtest data presented in this report is based on historical market conditions and simulated execution, which may not accurately reflect real-world trading outcomes. Actual results may vary due to slippage, liquidity, market regime changes, and other factors not fully captured in backtesting. This report is for informational purposes only and does not constitute financial advice or a guarantee of future returns.
    </p>
  </div>

</body>
</html>`;
}
