import { readFileSync } from "node:fs";
import { join } from "node:path";

export function readDeposit(reportDirectory) {
  const filepath = join(reportDirectory, "config.ini");
  const content = readFileSync(filepath, "utf-8");
  const match = content.match(/^Deposit=(\d+)/m);
  return match ? parseInt(match[1], 10) : 0;
}

export function readSummary(dataDirectory) {
  const filepath = join(dataDirectory, "summary.csv");
  const content = readFileSync(filepath, "utf-8");
  const lines = content.trim().split("\n");
  const metrics = {};

  for (let i = 1; i < lines.length; i++) {
    const separatorIndex = lines[i].indexOf(",");
    if (separatorIndex === -1) continue;
    const key = lines[i].slice(0, separatorIndex).trim().replace(/"/g, "");
    const value = lines[i].slice(separatorIndex + 1).trim().replace(/"/g, "");
    metrics[key] = value;
  }

  return metrics;
}
