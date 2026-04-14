import { LAYOUT } from "../../constants.js";
import { mono } from "../format.js";

export function renderPortfolioSummaryTable(summary, maxDrawdownDuration) {
  const backtestPeriod = summary.backtest_period;
  const startDate = backtestPeriod.split(" to ")[0];
  const endDate = backtestPeriod.split(" to ")[1];
  const startDateObj = new Date(startDate);
  const endDateObj = new Date(endDate);
  const backtestDays = Math.round(
    (endDateObj - startDateObj) / (1000 * 60 * 60 * 24),
  );

  const maxDdPctClean = summary.max_dd_pct.includes("(")
    ? summary.max_dd_pct.split("(")[0].trim()
    : summary.max_dd_pct;

  const winRateClean = summary.win_rate.includes("(")
    ? summary.win_rate.split("(")[1].replace(")", "")
    : summary.win_rate;

  const columns = [
    {
      title: "Performance",
      rows: [
        ["Return", mono(`${summary.total_return_pct.toFixed(1)}%`)],
        ["PnL", mono(`$${summary.total_pnl.toLocaleString("en-US", { maximumFractionDigits: 0 })}`)],
        ["Final Balance", mono(`$${summary.final_balance.toLocaleString("en-US", { maximumFractionDigits: 0 })}`)],
        ["Sharpe Ratio", mono(summary.sharpe_ratio.toFixed(2))],
        ["Profit Factor", mono(summary.profit_factor.toFixed(2))],
        ["Recovery Factor", mono(summary.recovery_factor.toFixed(2))],
        ["LR Correlation", mono(summary.lr_correlation.toFixed(2))],
      ],
    },
    {
      title: "Risk & Trading",
      rows: [
        ["Max Drawdown", mono(maxDdPctClean)],
        ["Max DD Duration", mono(`${maxDrawdownDuration} days`)],
        ["Win Rate", mono(winRateClean)],
        ["Trades", mono(summary.total_trades.toLocaleString())],
        ["Avg Holding Time", mono(summary.avg_hold_time)],
      ],
    },
    {
      title: "Portfolio",
      rows: [
        ["Backtest Period", mono(`${startDate} to ${endDate}`)],
        ["Backtest Duration", mono(`${backtestDays.toLocaleString()} days`)],
        ["Initial Balance", mono(`$${summary.initial_balance.toLocaleString("en-US", { maximumFractionDigits: 0 })}`)],
        ["Assets", mono(`${summary.assets_count}`)],
        ["Strategies", mono(`${summary.strategies_count}`)],
        ["Broker", mono("Vantage")],
        ["Minimum Capital", mono("$50,000")],
        ["Report Date", mono(new Date().toISOString().split("T")[0])],
      ],
    },
  ];

  const tables = columns.map((column) => {
    const bodyRows = column.rows
      .map(
        ([metric, value]) =>
          `<tr>
            <td style="font-weight: 700;">${metric}</td>
            <td style="text-align: right;">${value}</td>
          </tr>`,
      )
      .join("");

    return `
      <div>
        <table>
          <thead>
            <tr>
              <th style="text-align: left;">${column.title}</th>
              <th style="text-align: right;"></th>
            </tr>
          </thead>
          <tbody>${bodyRows}</tbody>
        </table>
      </div>
    `;
  });

  return `
    <h2>Portfolio Summary</h2>
    <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: ${LAYOUT.sectionGapPx}px;">
      ${tables.join("")}
    </div>
  `;
}
