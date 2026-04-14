import { ASSET_DISPLAY } from "../constants.js";
import { timestampToDate } from "../data/read_snapshots.js";

export function buildMarketData(marketSnapshotsBySymbol) {
  const markets = {};

  for (const [symbol, entries] of marketSnapshotsBySymbol) {
    if (!entries.length) continue;

    const firstPrice = entries[0].bid;
    const curve = entries.map((entry) => {
      const date = timestampToDate(entry.timestamp);
      const pct = ((entry.bid - firstPrice) / firstPrice) * 100;
      return {
        date,
        price: Math.round(entry.bid * 100) / 100,
        pct: Math.round(pct * 100) / 100,
      };
    });

    markets[symbol] = {
      display_name: ASSET_DISPLAY[symbol] || symbol,
      curve,
    };
  }

  return markets;
}
