import { COLORS, LAYOUT } from "../constants.js";
import { renderChartToSvg } from "./render_chart.js";

export function renderPortfolioDrawdown(dailyDrawdown) {
  const dates = dailyDrawdown.map((e) => e.date.slice(0, 7));
  const values = dailyDrawdown.map((e) => ({
    value: -e.drawdown,
    itemStyle: { color: COLORS.black },
  }));

  const option = {
    grid: { left: 50, right: 20, top: 10, bottom: 30 },
    tooltip: {
      trigger: "axis",
      formatter: (params) => {
        const value = Math.abs(params[0].value);
        return `${params[0].name}<br/>Drawdown: ${value.toFixed(2)}%`;
      },
    },
    xAxis: {
      type: "category",
      data: dates,
      axisLabel: {
        fontSize: LAYOUT.fontSizeChartAxisPx,
        interval: Math.max(1, Math.floor(dates.length / 8)),
      },
    },
    yAxis: {
      type: "value",
      axisLabel: { fontSize: LAYOUT.fontSizeChartAxisPx, formatter: (v) => `${Math.abs(v).toFixed(0)}%` },
      splitLine: { show: false },
    },
    series: [
      {
        type: "bar",
        data: values,
        barWidth: "100%",
        large: true,
      },
    ],
  };

  return renderChartToSvg(option, LAYOUT.chartWidthPx, LAYOUT.chartHeightSmallPx);
}
