#!/usr/bin/env node

import { existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { log, STEPS } from "./report/logger.js";
import { readSummary, readDeposit } from "./report/data/read_summary.js";
import { readMarketSnapshots } from "./report/data/read_snapshots.js";
import { readOrders } from "./report/data/read_orders.js";
import { buildPortfolioEquity } from "./report/transform/portfolio_equity.js";
import { buildMonthlyReturns } from "./report/transform/monthly_returns.js";
import { buildAssetData } from "./report/transform/asset_data.js";
import { buildStrategyData } from "./report/transform/strategy_data.js";
import { buildMarketData } from "./report/transform/market_data.js";
import { buildDrawdown } from "./report/transform/drawdown.js";
import { buildPortfolioSummary } from "./report/transform/portfolio_summary.js";
import { buildIntroText } from "./report/constants.js";
import { renderPortfolioVsMarket } from "./report/charts/portfolio_vs_market.js";
import { renderPortfolioDrawdown } from "./report/charts/portfolio_drawdown.js";
import { renderAssetEquity } from "./report/charts/asset_equity.js";
import { renderStrategyEquity } from "./report/charts/strategy_equity.js";
import { buildHtml } from "./report/template/build_html.js";
import { renderHtmlToPdf } from "./report/pdf/render_pdf.js";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const STORAGE_DIR = join(SCRIPT_DIR, "storage");

async function main() {
  const reportPath = process.argv[2];
  const reportName = process.argv[3] || `HZ5_${Date.now()}`;

  if (!reportPath) {
    console.error("Usage: node generate_report.js <report_path> [report_name]");
    console.error(
      "Example: node generate_report.js /path/to/storage/results/1744329600 MyReport",
    );
    console.error(
      "  If report_name is omitted, defaults to HZ5_{timestamp}",
    );
    process.exit(1);
  }

  const resolvedReportPath = resolve(reportPath);

  if (!existsSync(resolvedReportPath)) {
    console.error(`Report path does not exist: ${resolvedReportPath}`);
    process.exit(1);
  }

  const seedDirectory = join(resolvedReportPath, "seed");
  const dataDirectory = join(resolvedReportPath, "data");

  if (!existsSync(seedDirectory)) {
    console.error(`Seed directory not found: ${seedDirectory}`);
    process.exit(1);
  }

  if (!existsSync(dataDirectory)) {
    console.error(`Data directory not found: ${dataDirectory}`);
    process.exit(1);
  }

  log(STEPS.clean, "Cleaning storage directory...");
  if (existsSync(STORAGE_DIR)) {
    rmSync(STORAGE_DIR, { recursive: true });
  }
  mkdirSync(STORAGE_DIR, { recursive: true });

  log(STEPS.read, "Reading config.ini deposit...");
  const deposit = readDeposit(resolvedReportPath);
  log(STEPS.read, `  Deposit: $${deposit.toLocaleString()}`);

  log(STEPS.read, "Reading summary CSV...");
  const csvMetrics = readSummary(dataDirectory);
  log(STEPS.read, `  Found ${Object.keys(csvMetrics).length} metrics`);

  log(STEPS.read, "Reading order files...");
  const ordersByStrategy = readOrders(seedDirectory);
  log(STEPS.read, `  Found ${ordersByStrategy.size} strategy order sets`);

  log(STEPS.read, "Reading market snapshots...");
  const marketSnapshotsBySymbol = readMarketSnapshots(seedDirectory);
  log(STEPS.read, `  Found ${marketSnapshotsBySymbol.size} market symbols`);

  log(STEPS.transform, "Building portfolio equity curve (from orders)...");
  const { equityCurve, initialBalance } =
    buildPortfolioEquity(ordersByStrategy, deposit);
  log(
    STEPS.transform,
    `  ${equityCurve.length} data points, initial balance: $${initialBalance.toLocaleString()}`,
  );

  log(STEPS.transform, "Computing drawdown...");
  const { dailyDrawdown, maxDrawdownDuration } = buildDrawdown(equityCurve);
  log(
    STEPS.transform,
    `  Max drawdown duration: ${maxDrawdownDuration} days`,
  );

  log(STEPS.transform, "Building monthly returns grid...");
  const monthlyReturns = buildMonthlyReturns(equityCurve);
  log(
    STEPS.transform,
    `  ${Object.keys(monthlyReturns).length} years of data`,
  );

  log(STEPS.transform, "Building asset data (from orders)...");
  const assetData = buildAssetData(ordersByStrategy, deposit);
  log(STEPS.transform, `  ${Object.keys(assetData).length} assets processed`);

  log(STEPS.transform, "Building strategy data (from orders)...");
  const allDates = equityCurve.map((e) => e.date);
  const strategyData = buildStrategyData(ordersByStrategy, deposit, allDates);
  log(STEPS.transform, `  ${strategyData.length} strategies processed`);

  log(STEPS.transform, "Building market data...");
  const marketData = buildMarketData(marketSnapshotsBySymbol);
  log(
    STEPS.transform,
    `  ${Object.keys(marketData).length} market curves built`,
  );

  log(STEPS.transform, "Building portfolio summary...");
  const summary = buildPortfolioSummary(
    csvMetrics,
    equityCurve,
    deposit,
    maxDrawdownDuration,
  );
  log(
    STEPS.transform,
    `  Return: ${summary.total_return_pct.toFixed(1)}%, Trades: ${summary.total_trades}`,
  );

  log(STEPS.export, "Exporting JSON files to storage...");
  writeFileSync(
    join(STORAGE_DIR, "portfolio_summary.json"),
    JSON.stringify(summary, null, 2),
  );
  writeFileSync(
    join(STORAGE_DIR, "portfolio_equity.json"),
    JSON.stringify(equityCurve),
  );
  writeFileSync(
    join(STORAGE_DIR, "monthly_returns.json"),
    JSON.stringify(monthlyReturns, null, 2),
  );

  const assetOutput = {};
  for (const [symbol, data] of Object.entries(assetData)) {
    const { equity_curve, ...rest } = data;
    assetOutput[symbol] = rest;
    writeFileSync(
      join(STORAGE_DIR, `asset_${symbol}_equity.json`),
      JSON.stringify(equity_curve),
    );
  }
  writeFileSync(
    join(STORAGE_DIR, "assets.json"),
    JSON.stringify(assetOutput, null, 2),
  );

  const strategySummary = strategyData.map(({ equity_curve, ...rest }) => rest);
  writeFileSync(
    join(STORAGE_DIR, "strategies.json"),
    JSON.stringify(strategySummary, null, 2),
  );
  for (const strategy of strategyData) {
    writeFileSync(
      join(
        STORAGE_DIR,
        `strategy_${strategy.symbol}_${strategy.prefix}_equity.json`,
      ),
      JSON.stringify(strategy.equity_curve),
    );
  }

  const marketOutput = {};
  for (const [symbol, data] of Object.entries(marketData)) {
    marketOutput[symbol] = data.curve;
  }
  writeFileSync(
    join(STORAGE_DIR, "markets.json"),
    JSON.stringify(marketOutput),
  );
  log(STEPS.export, "  JSON export complete");

  log(STEPS.charts, "Rendering Portfolio vs Market chart...");
  const portfolioVsMarketSvg = renderPortfolioVsMarket(
    equityCurve,
    marketData,
  );

  log(STEPS.charts, "Rendering Drawdown chart...");
  const drawdownSvg = renderPortfolioDrawdown(dailyDrawdown);

  log(STEPS.charts, "Rendering Asset Equity chart...");
  const assetEquitySvg = renderAssetEquity(assetData);

  log(STEPS.charts, "Rendering Strategy Equity chart...");
  const strategyEquityChart = renderStrategyEquity(strategyData);
  log(STEPS.charts, "  All charts rendered");

  log(STEPS.template, "Building HTML document...");
  const introText = buildIntroText(summary, monthlyReturns);
  const htmlContent = buildHtml({
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
  });

  const htmlPath = join(STORAGE_DIR, `${reportName}.html`);
  writeFileSync(htmlPath, htmlContent);
  log(STEPS.template, `  HTML saved to: ${htmlPath}`);

  log(STEPS.pdf, "Generating PDF with Playwright...");
  const pdfPath = join(STORAGE_DIR, `${reportName}.pdf`);
  await renderHtmlToPdf(htmlContent, pdfPath);
  log(STEPS.pdf, `  PDF saved to: ${pdfPath}`);

  log(STEPS.done, "Report generation complete!");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
