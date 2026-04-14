import * as echarts from "echarts";

export function renderChartToSvg(option, width, height) {
  const chart = echarts.init(null, null, {
    renderer: "svg",
    ssr: true,
    width,
    height,
  });
  chart.setOption({ ...option, animation: false });
  const svgString = chart.renderToSVGString();
  chart.dispose();
  return svgString;
}
