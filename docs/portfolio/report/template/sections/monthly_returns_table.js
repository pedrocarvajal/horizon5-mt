import { COLORS } from "../../constants.js";
import { mono } from "../format.js";

const MONTH_LABELS = [
  "Year", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec", "Total",
];

export function renderMonthlyReturnsTable(monthlyReturns) {
  const years = Object.keys(monthlyReturns).sort();

  const headerCells = MONTH_LABELS.map(
    (label) => `<th style="text-align: center;">${label}</th>`,
  ).join("");

  const bodyRows = years.map((year) => {
    const yearCell = `<td style="text-align: center; font-weight: 600;">${mono(year)}</td>`;

    const monthCells = Array.from({ length: 12 }, (_, i) => {
      const month = i + 1;
      const value = monthlyReturns[year][month];
      if (value === undefined) {
        return `<td></td>`;
      }
      const textColor = value >= 0 ? COLORS.positive : COLORS.negative;
      return `<td style="text-align: center; color: ${textColor};">${mono(`${value.toFixed(2)}%`)}</td>`;
    }).join("");

    const totalValue = monthlyReturns[year].total;
    const totalColor = totalValue !== undefined
      ? totalValue >= 0 ? COLORS.positive : COLORS.negative
      : "";
    const totalCell = `<td style="text-align: center; font-weight: 700; background: #f3f4f6; color: ${totalColor};">${totalValue !== undefined ? mono(`${totalValue.toFixed(2)}%`) : ""}</td>`;

    return `<tr>${yearCell}${monthCells}${totalCell}</tr>`;
  }).join("");

  return `
    <h2>Monthly Returns %</h2>
    <table>
      <thead><tr>${headerCells}</tr></thead>
      <tbody>${bodyRows}</tbody>
    </table>
  `;
}
