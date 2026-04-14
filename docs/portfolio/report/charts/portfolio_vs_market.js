import { ASSET_COLORS, ASSET_DISPLAY, COLORS, LAYOUT } from "../constants.js";
import { renderChartToSvg } from "./render_chart.js";

export function renderPortfolioVsMarket(equityCurve, marketData) {
  const dates = equityCurve.map((e) => e.date.slice(0, 7));
  const portfolioPcts = equityCurve.map((e) => e.pct);

  const series = [
    {
      name: "Portfolio",
      type: "line",
      data: portfolioPcts,
      lineStyle: { width: 2, color: COLORS.black },
      itemStyle: { color: COLORS.black },
      showSymbol: false,
      z: 10,
    },
  ];

  for (const [symbol, data] of Object.entries(marketData)) {
    const marketPctByDate = new Map(data.curve.map((m) => [m.date, m.pct]));
    const marketPcts = [];
    let lastValue = 0;
    for (const entry of equityCurve) {
      const value = marketPctByDate.get(entry.date);
      if (value !== undefined) lastValue = value;
      marketPcts.push(lastValue);
    }

    series.push({
      name: ASSET_DISPLAY[symbol] || symbol,
      type: "line",
      data: marketPcts,
      lineStyle: { width: 1, color: ASSET_COLORS[symbol] || COLORS.gray },
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
      data: dates,
      axisLabel: {
        fontSize: LAYOUT.fontSizeChartAxisPx,
        interval: Math.max(1, Math.floor(dates.length / 8)),
      },
      axisTick: { alignWithLabel: true },
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
