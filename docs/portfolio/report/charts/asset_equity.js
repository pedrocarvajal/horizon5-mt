import { ASSET_COLORS, ASSET_DISPLAY, COLORS, LAYOUT } from "../constants.js";
import { renderChartToSvg } from "./render_chart.js";

export function renderAssetEquity(assetData) {
  const series = [];
  let referenceDates = [];

  for (const [symbol, data] of Object.entries(assetData)) {
    const pcts = data.equity_curve.map((e) => e.pct);
    if (!referenceDates.length) {
      referenceDates = data.equity_curve.map((e) => e.date.slice(0, 7));
    }

    series.push({
      name: ASSET_DISPLAY[symbol] || symbol,
      type: "line",
      data: pcts,
      lineStyle: { width: 1.2, color: ASSET_COLORS[symbol] || COLORS.gray },
      itemStyle: { color: ASSET_COLORS[symbol] || COLORS.gray },
      showSymbol: false,
    });
  }

  const option = {
    grid: { left: 50, right: 20, top: 30, bottom: 30 },
    tooltip: { trigger: "axis" },
    legend: {
      data: series.map((s) => s.name),
      top: 0,
      right: 0,
      icon: "rect",
      itemWidth: 14,
      itemHeight: 3,
      textStyle: { fontSize: LAYOUT.fontSizeChartLegendPx },
    },
    xAxis: {
      type: "category",
      data: referenceDates,
      axisLabel: {
        fontSize: LAYOUT.fontSizeChartAxisPx,
        interval: Math.max(1, Math.floor(referenceDates.length / 8)),
      },
    },
    yAxis: {
      type: "value",
      axisLabel: { fontSize: LAYOUT.fontSizeChartAxisPx, formatter: "{value}%" },
      splitLine: { lineStyle: { color: COLORS.grid } },
    },
    series,
  };

  return renderChartToSvg(option, LAYOUT.chartWidthPx, LAYOUT.chartHeightPx);
}
