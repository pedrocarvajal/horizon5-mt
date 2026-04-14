import { readFileSync, readdirSync } from "node:fs";
import { join, basename } from "node:path";

function timestampToDate(timestamp) {
  return new Date(timestamp * 1000).toISOString().split("T")[0];
}

function deduplicateSnapshots(entries) {
  const byDate = new Map();
  for (const entry of entries) {
    const date = timestampToDate(entry.timestamp);
    const existing = byDate.get(date);
    if (!existing || entry.timestamp > existing.timestamp) {
      byDate.set(date, entry);
    }
  }
  return Array.from(byDate.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([, entry]) => entry);
}

export function readSnapshots(seedDirectory) {
  const files = readdirSync(seedDirectory).filter(
    (file) =>
      file.endsWith("_Snapshots.json") &&
      !file.includes("_MARKET_") &&
      !file.includes("_GWY_"),
  );

  const snapshotsByStrategy = new Map();

  for (const file of files) {
    const parts = basename(file, "_Snapshots.json").split("_");
    const symbol = parts[0];
    const prefix = parts[1];
    const key = `${symbol}_${prefix}`;

    const raw = JSON.parse(readFileSync(join(seedDirectory, file), "utf-8"));
    if (!raw.length) continue;

    snapshotsByStrategy.set(key, {
      symbol,
      prefix,
      entries: deduplicateSnapshots(raw),
    });
  }

  return snapshotsByStrategy;
}

export function readMarketSnapshots(seedDirectory) {
  const files = readdirSync(seedDirectory).filter(
    (file) =>
      file.includes("_MARKET_") && file.endsWith("_Snapshots.json"),
  );

  const marketsBySymbol = new Map();

  for (const file of files) {
    const symbol = basename(file).split("_MARKET_")[0];
    const raw = JSON.parse(readFileSync(join(seedDirectory, file), "utf-8"));
    if (!raw.length) continue;

    marketsBySymbol.set(symbol, deduplicateSnapshots(raw));
  }

  return marketsBySymbol;
}

export { timestampToDate };
