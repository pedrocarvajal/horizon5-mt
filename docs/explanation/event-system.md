# Event System

Horizon5 decouples strategy events from MT5's native `OnTick` (which fires only on price changes) by driving everything from a 1-second timer and from **primed-bar detection** on each asset's symbol.

## Why not native `OnTick`?

Native `OnTick` is irregular by definition: it fires only when the broker sends a price. A strategy that wants to evaluate "at the start of every hour" cannot rely on it — during quiet sessions hours can pass with no ticks. Horizon5 replaces that with two deterministic signals:

1. A **1-second system timer** (`EventSetTimer(1)` → `OnTimer()`) — guaranteed cadence.
2. **Primed-bar detection** per asset — a `OnStartMinute / OnStartHour / OnStartDay` fires exactly when a new M1/H1/D1 bar opens for the asset's symbol, regardless of whether a tick arrived on the chart the EA is attached to.

## Priming

When an asset starts up, it reads `iTime(symbol, PERIOD_*, 0)` and records the current bar open without firing an event. This is the **prime** step. Only on the _next_ bar transition does the event fire. The priming step prevents spurious fires on startup and after gaps.

## Dispatch order

Every 1-second tick of the timer runs, in order:

1. `asset.OnTimer()` → `strategy.OnTimer()` on every asset/strategy.
2. `asset.ProcessBarEvents()` → may fire `OnStartMinute / OnStartHour / OnStartDay`, each of which cascades to strategies.
3. If the calendar day-of-year changed: daily maintenance, Monitor sync on `SNAPSHOT_ON_END_DAY`, and seed snapshot collection.
4. If the calendar hour changed: Monitor hourly sync (if different from daily) and service heartbeats.
5. If the calendar minute changed: service health check.
6. If the tick interval elapsed: `asset.OnTick()` → `strategy.OnTick()`.
7. `asset.ProcessOrders()` → order-book retries, submissions, and transitions.
8. Gateway drains inbound service events (if enabled).
9. Hourly: account auditor runs.

Steps 3–5 rely on calendar-time comparisons via `SEDateTime`; steps 1 and 2 are independent of calendar comparisons.

## Why two signals for hour/day?

Step 2 (primed-bar) fires once per asset when that asset's symbol sees a new bar. Step 3–5 (calendar-time) fire once globally regardless of market hours. The framework uses primed-bar events for strategy logic (so you only evaluate when your market actually advances) and uses calendar-time edges for portfolio-wide maintenance (Monitor sync, service health, auditing).

## Trade transactions

`OnTradeTransaction` is outside the timer loop — it fires whenever the broker delivers a transaction. The EA handles:

- `DEAL_ENTRY_IN` — a new fill; route by MT5 order ticket and transition to `OPEN`.
- `DEAL_ENTRY_OUT` — an exit; route by position ID and transition to `CLOSED`.
- `ORDER_STATE_CANCELED` / `ORDER_STATE_EXPIRED` on `HISTORY_ADD` — a pending broker order was abandoned; transition to `CANCELLED`.

## Strategy callbacks

All callbacks listed in [Reference > Event System](../reference/event-system.md). The key insight: **no callback fires more than once per underlying event**. `OnStartHour` fires exactly once per hour bar per strategy; `OnOpenOrder` fires exactly once per fill; etc. Idempotency inside strategy code is still recommended, but the framework does not fan out events.
