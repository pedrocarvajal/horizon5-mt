import { chromium } from "playwright";

export async function renderHtmlToPdf(htmlContent, outputPath) {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  await page.setContent(htmlContent, { waitUntil: "networkidle" });

  const bodyHeight = await page.evaluate(() => document.body.scrollHeight);
  const pageHeightInches = Math.ceil(bodyHeight / 96) + 1;

  await page.pdf({
    path: outputPath,
    width: "11.69in",
    height: `${pageHeightInches}in`,
    printBackground: true,
    margin: { top: "0.3in", bottom: "0.3in", left: "0in", right: "0in" },
  });

  await browser.close();
}
