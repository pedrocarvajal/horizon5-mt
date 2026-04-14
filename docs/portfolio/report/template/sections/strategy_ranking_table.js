import { ASSET_COLORS, ASSET_DISPLAY } from "../../constants.js";
import { mono } from "../format.js";

export function renderStrategyRankingTable(strategyData) {
  const headerCells = [
    '<th style="text-align: center; width: 30px;">#</th>',
    '<th style="text-align: left;">Strategy</th>',
    '<th style="text-align: left;">Asset</th>',
    '<th style="text-align: right;">Return</th>',
    '<th style="text-align: right;">PnL</th>',
    '<th style="text-align: right;">Trades</th>',
    '<th style="text-align: right;">Win Rate</th>',
    '<th style="text-align: right;">Profit Factor</th>',
    '<th style="text-align: right;">Max DD</th>',
  ].join("");

  const sorted = [...strategyData].sort(
    (a, b) => b.performance_pct - a.performance_pct,
  );

  const bodyRows = sorted
    .map((strategy, index) => {
      const color = ASSET_COLORS[strategy.symbol] || "#000000";
      const assetName = ASSET_DISPLAY[strategy.symbol] || strategy.symbol;
      const pnl = strategy.final_nav - strategy.initial_nav;

      return `<tr>
        <td style="text-align: center;">${mono(index + 1)}</td>
        <td style="font-weight: 700;">${strategy.name}</td>
        <td><span style="color: ${color};">*</span> ${assetName}</td>
        <td style="text-align: right;">${mono(`${strategy.performance_pct.toFixed(1)}%`)}</td>
        <td style="text-align: right;">${mono(`$${pnl.toLocaleString("en-US", { maximumFractionDigits: 0 })}`)}</td>
        <td style="text-align: right;">${mono(strategy.total_trades.toLocaleString())}</td>
        <td style="text-align: right;">${mono(`${strategy.win_rate.toFixed(2)}%`)}</td>
        <td style="text-align: right;">${mono(strategy.profit_factor.toFixed(2))}</td>
        <td style="text-align: right;">${mono(`${strategy.max_dd_pct.toFixed(2)}%`)}</td>
      </tr>`;
    })
    .join("");

  return `
    <h2>Strategy Ranking</h2>
    <table>
      <thead><tr>${headerCells}</tr></thead>
      <tbody>${bodyRows}</tbody>
    </table>
  `;
}
