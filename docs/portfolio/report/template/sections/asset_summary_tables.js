import { ASSET_COLORS, ASSET_DISPLAY, LAYOUT } from "../../constants.js";
import { mono } from "../format.js";

export function renderAssetSummaryTables(assetData) {
  const symbols = Object.keys(assetData);

  const tables = symbols.map((symbol) => {
    const data = assetData[symbol];
    const color = ASSET_COLORS[symbol] || "#000000";
    const displayName = ASSET_DISPLAY[symbol] || symbol;

    const rows = [
      ["Return", mono(`${data.total_pct.toFixed(1)}%`)],
      ["PnL", mono(`$${data.total_pnl.toLocaleString("en-US", { maximumFractionDigits: 0 })}`)],
      ["Strategies", mono(`${data.strategy_count}`)],
      ["Trades", mono(`${data.total_trades.toLocaleString()}`)],
      ["Win Rate", mono(`${data.win_rate.toFixed(2)}%`)],
      ["Profit Factor", mono(`${data.profit_factor.toFixed(2)}`)],
    ];

    const bodyRows = rows.map(
      ([metric, value]) =>
        `<tr>
          <td style="font-weight: 700;">${metric}</td>
          <td style="text-align: right;">${value}</td>
        </tr>`,
    ).join("");

    return `
      <div>
        <h3>${displayName} <span style="color: ${color}; font-size: ${LAYOUT.fontSizeTitlePx}px;">*</span></h3>
        <table>
          <thead>
            <tr>
              <th style="text-align: left;">Metric</th>
              <th style="text-align: right;"></th>
            </tr>
          </thead>
          <tbody>${bodyRows}</tbody>
        </table>
      </div>
    `;
  });

  return `
    <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: ${LAYOUT.sectionGapPx}px;">
      ${tables.join("")}
    </div>
  `;
}
