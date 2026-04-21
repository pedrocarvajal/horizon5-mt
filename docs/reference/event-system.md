# Event System

Horizon5 turns MetaTrader 5's single-threaded tick callback into a deterministic, time-driven and bar-driven event pipeline. Strategies see consistent events regardless of broker tick frequency.

## Timer

`OnInit()` calls `EventSetTimer(1)`, producing a 1-second timer. On every tick of that timer, `OnTimer()` runs the orchestration loop:

1. Dispatch `OnTimer()` to every asset (and through the asset to every strategy).
2. Dispatch **primed bar events** (see below) via `SEAsset.ProcessBarEvents()`.
3. When `isStartDay` flips, run daily maintenance (unpause non-critical pauses, sync Monitor, collect seed snapshots).
4. When `isStartMinute` flips, run `CheckServiceHealth()`.
5. When the tick interval elapses, dispatch `OnTick()` to every asset/strategy.
6. After all events, dispatch `ProcessOrders()` to every asset so order books process pending transitions and retries.
7. If Gateway is enabled, drain inbound service events.
8. When `isStartHour` flips and Monitor is enabled, run hourly Monitor sync and service heartbeats.
9. When `isStartHour` flips, run the account auditor.

## Tick interval

`TickIntervalTime` (default 60s) controls `OnTick` dispatch frequency. The EA compares `now.timestamp - lastTickTime` against the input and fires `OnTick` when the threshold is reached.

## Primed-bar events

`OnStartMinute`, `OnStartHour`, and `OnStartDay` are driven by **bar-open detection**, not wall-clock comparisons. Each `SEAsset` records the last seen bar open for M1, H1, and D1 via `iTime()`. When the next bar opens:

1. On the **first** detection the flag is primed (`m1Primed / h1Primed / d1Primed`); the event is not fired. This prevents a spurious fire on startup or after gaps.
2. On subsequent transitions the event fires for every asset (and propagates to every strategy).

This means events are scoped per asset's symbol and only fire when that symbol actually prints a new bar.

## Propagation chain

```
Horizon.mq5::OnTimer()
  ├── asset.OnTimer()                 → strategy.OnTimer()
  ├── asset.ProcessBarEvents()
  │       ├── asset.OnStartMinute()   → strategy.OnStartMinute()
  │       ├── asset.OnStartHour()     → strategy.OnStartHour()
  │       └── asset.OnStartDay()      → strategy.OnStartDay()
  ├── (isStartDay)  daily maintenance + monitor sync
  ├── (isStartMinute) CheckServiceHealth()
  ├── (isTickInterval) asset.OnTick() → strategy.OnTick()
  ├── asset.ProcessOrders()           → strategy order book retries/submits
  ├── gateway.ProcessServiceEvents()
  └── (isStartHour) monitor sync, heartbeats, account audit
```

## Trade transactions

`OnTradeTransaction` is an MT5 native callback fired by broker-side events. The EA handles:

- `TRADE_TRANSACTION_DEAL_ADD` with `DEAL_ENTRY_IN` — a new position is live. The EA looks up the owning order by MT5 order ticket and moves it to `OPEN`.
- `TRADE_TRANSACTION_DEAL_ADD` with `DEAL_ENTRY_OUT` — a position closed. The EA computes net P&L (`profit + commission * 2 + swap`) and moves the order to `CLOSED`.
- `TRADE_TRANSACTION_HISTORY_ADD` with `ORDER_STATE_CANCELED` or `ORDER_STATE_EXPIRED` — a pending broker order was abandoned. The owning order transitions to `CANCELLED`.

Routing is by magic number: the EA walks the asset array and delegates to the asset that owns the matching magic.

## Strategy callbacks

Strategies implement `IStrategy`. The callbacks that fire as a result of the loop:

| Callback                                   | When                                                                               |
| ------------------------------------------ | ---------------------------------------------------------------------------------- |
| `OnInit()` / `OnTesterInit()`              | Startup (live or tester).                                                          |
| `OnTimer()`                                | Every second.                                                                      |
| `OnTick()`                                 | At the configured tick interval.                                                   |
| `OnStartMinute / OnStartHour / OnStartDay` | When a new M1/H1/D1 bar opens on the strategy's symbol.                            |
| `OnPendingOrderPlaced(order)`              | After a pending order is created in the book.                                      |
| `OnOpenOrder(order)`                       | After the broker confirms a fill.                                                  |
| `OnOrderUpdated(order)`                    | After an order's fields are modified (e.g. SL/TP).                                 |
| `OnCloseOrder(order, reason)`              | After the broker confirms the exit.                                                |
| `OnCancelOrder(order)`                     | After a pending order is cancelled/expired or a close request is rejected finally. |
| `OnEnd()`                                  | On normal EA shutdown (not chart/param change). Safe for final I/O.                |
| `OnDeinit()`                               | On every deinit. **No remote or heavy I/O** — local cleanup only.                  |
