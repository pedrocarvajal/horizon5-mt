import { STRATEGY_PALETTE, COLORS, LAYOUT } from "../constants.js";
import { renderChartToSvg } from "./render_chart.js";

export function renderStrategyEquity(strategyData) {
  const series = [];
  let referenceDates = [];

  for (let i = 0; i < strategyData.length; i++) {
    const strategy = strategyData[i];
    const color = STRATEGY_PALETTE[i % STRATEGY_PALETTE.length];
    const initialNav =
      strategy.equity_curve[0]?.nav !== 0 ? strategy.equity_curve[0]?.nav : 1;

    const pcts = strategy.equity_curve.map(
      (e) => ((e.nav - initialNav) / initialNav) * 100,
    );

    if (!referenceDates.length) {
      referenceDates = strategy.equity_curve.map((e) => e.date.slice(0, 7));
    }

    series.push({
      name: strategy.name,
      type: "line",
      data: pcts,
      lineStyle: { width: 0.8, color, opacity: 0.85 },
      itemStyle: { color },
      showSymbol: false,
    });
  }

  const option = {
    grid: { left: 50, right: 20, top: 10, bottom: 30 },
    tooltip: { trigger: "axis", confine: true },
    legend: { show: false },
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

  const svgChart = renderChartToSvg(option, LAYOUT.chartWidthPx, LAYOUT.chartHeightPx);

  const legendItems = strategyData.map((strategy, i) => {
    const color = STRATEGY_PALETTE[i % STRATEGY_PALETTE.length];
    return `<span style="display: inline-flex; align-items: center; gap: 4px; white-space: nowrap;">
      <span style="display: inline-block; width: 14px; height: 3px; background: ${color};"></span>
      <span style="font-size: 9px; color: #374151;">${strategy.name}</span>
    </span>`;
  });

  const legendHtml = `<div style="display: flex; flex-wrap: wrap; gap: 6px 16px; margin-bottom: 8px;">${legendItems.join("")}</div>`;

  return { svgChart, legendHtml };
}
