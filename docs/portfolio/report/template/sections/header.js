import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { PAPER_TRADING_URL, LAYOUT } from "../../constants.js";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PORTFOLIO_DIR = join(SCRIPT_DIR, "..", "..", "..");

export function renderHeader(introText) {
  const logoPath = join(PORTFOLIO_DIR, "Logo.png");
  const logoBase64 = readFileSync(logoPath).toString("base64");
  const logoDataUri = `data:image/png;base64,${logoBase64}`;

  const midParagraph = Math.ceil(introText.length / 2);
  const leftParagraphs = introText.slice(0, midParagraph);
  const rightParagraphs = introText.slice(midParagraph);

  return `
    <div class="section" style="display: flex; align-items: center; gap: ${LAYOUT.blockGapPx}px; margin-bottom: ${LAYOUT.blockGapPx}px;">
      <img src="${logoDataUri}" alt="Horizon5" style="width: ${LAYOUT.logoSizePx}px; height: ${LAYOUT.logoSizePx}px; border-radius: 8px;" />
      <span style="font-size: ${LAYOUT.fontSizeLogoPx}px; font-weight: 700;">Horizon5</span>
    </div>

    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: ${LAYOUT.sectionGapPx}px; margin-bottom: ${LAYOUT.blockGapPx}px;">
      <div style="color: #6b7280; font-size: ${LAYOUT.fontSizeSmallPx}px; line-height: 1.6;">
        ${leftParagraphs.map((p) => `<p style="margin-bottom: ${LAYOUT.blockGapPx / 2}px;">${p}</p>`).join("")}
      </div>
      <div style="color: #6b7280; font-size: ${LAYOUT.fontSizeSmallPx}px; line-height: 1.6;">
        ${rightParagraphs.map((p) => `<p style="margin-bottom: ${LAYOUT.blockGapPx / 2}px;">${p}</p>`).join("")}
      </div>
    </div>

    <div style="font-size: ${LAYOUT.fontSizeSmallPx}px; color: #6b7280; margin-bottom: ${LAYOUT.blockGapPx / 2}px;">
      Paper trading track record: <a href="${PAPER_TRADING_URL}" style="color: #2563eb; text-decoration: underline;">${PAPER_TRADING_URL.replace("https://www.", "")}</a>
    </div>

    <div class="section" style="font-size: ${LAYOUT.fontSizeSmallPx}px; color: #6b7280;">
      Author: <strong style="color: #111827;">Pedro Carvajal</strong>
    </div>
  `;
}
