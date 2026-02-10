# Strategy State Persistence

## Problem

Strategies maintain in-memory state (flags, counters, timestamps) that is lost when the terminal restarts. There is no mechanism to persist arbitrary strategy data across restarts.

## Where It Happens

- `strategies/Strategy.mqh` - The base class holds fields like `countOrdersOfToday` (line 32) that reset to 0 on every `OnInit()` call. When the terminal restarts mid-day, the counter resets and the strategy loses track of how many orders it already opened.

- `strategies/Bloemfontein/Bloemfontein.mqh` - Example consumer. Uses `maxOrdersPerDay` to limit daily orders, but after a restart it thinks zero orders were opened today and may open duplicates.

- Any strategy extending `SEStrategy` faces the same problem for any custom state they track (custom flags, internal counters, cached values).

## What Exists Today

- `services/SEOrderPersistence/SEOrderPersistence.mqh` - Persists individual **order** data to JSON files, restoring open orders on restart. This solves order recovery but does not cover arbitrary strategy-level state.

- Order persistence is gated by `isLiveTrading()` and only runs in live mode. The same constraint applies to this problem - state loss only matters in live trading.

## Objective

Provide a way for strategies to save and restore arbitrary key-value data that survives terminal restarts, so that strategy-level state (flags, counters, timestamps) is not lost.
