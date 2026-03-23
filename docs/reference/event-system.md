# Event System

Horizon5 uses a timer-based event system instead of relying on MetaTrader's native `OnTick` (which only fires on price changes). This guarantees consistent strategy evaluation regardless of market activity.

## Timer Configuration

The EA calls `EventSetTimer(1)` during `OnInit`, creating a 1-second system timer. Each second, `OnTimer` runs and checks whether any logical events should fire based on time comparisons.

### TickIntervalTime

The `TickIntervalTime` input (default: 60 seconds) controls how often `OnTick` is dispatched to strategies. The EA compares the current timestamp against `lastTickTime` and fires only when the elapsed time meets or exceeds the configured interval.

## Events

### OnTimer

Fires every second (system timer). Used internally by assets and strategies for low-level polling that must happen frequently, such as order processing and service event consumption.

### OnTick

Fires every `TickIntervalTime` seconds. This is the primary strategy evaluation event. Strategies check indicators and generate entry/exit signals here.

### OnStartMinute

Fires once when the minute changes. Used for service health checks (`CheckServiceHealth`) and minute-resolution tasks.

### OnStartHour

Fires once when the hour changes. Used for periodic sync with external APIs (e.g., `horizonMonitor.SyncAccount`).

### OnStartDay

Fires once when the day-of-year changes. Used for daily resets such as clearing non-critical trading pauses.

## Propagation Chain

Events propagate from the main EA file through assets to individual strategies:

```
Horizon.mq5 OnTimer()
  |
  +-- for each asset: asset.OnTimer()
  |     +-- for each strategy: strategy.OnTimer()
  |
  +-- if isStartDay:
  |     +-- for each asset: asset.OnStartDay()
  |           +-- for each strategy: strategy.OnStartDay()
  |
  +-- if isStartHour:
  |     +-- for each asset: asset.OnStartHour()
  |           +-- for each strategy: strategy.OnStartHour()
  |
  +-- if isStartMinute:
  |     +-- for each asset: asset.OnStartMinute()
  |           +-- for each strategy: strategy.OnStartMinute()
  |
  +-- if isTickInterval:
  |     +-- for each asset: asset.OnTick()
  |           +-- for each strategy: strategy.OnTick()
  |
  +-- for each asset: asset.ProcessOrders()
  +-- horizonGateway.ProcessServiceEvents(assets)
```

## Trade Transaction Callbacks

`OnTradeTransaction` is a MetaTrader 5 native callback that fires when broker-side events occur (deal executed, order cancelled, etc.). Horizon5 handles two entry types:

- **DEAL_ENTRY_IN** -- A new position was opened. The EA matches the deal to the correct order via `orderId` and updates it to OPEN state.
- **DEAL_ENTRY_OUT** -- A position was closed. The EA matches via `positionId`, records final prices and profit, and transitions the order to CLOSED state.
- **ORDER_STATE_CANCELED / ORDER_STATE_EXPIRED** -- A pending broker order was cancelled or expired. The EA propagates cancellation to the matching internal order.

## Strategy Callbacks

Strategies implement the `IStrategy` interface, which includes:

- `OnOpenOrder(EOrder &order)` -- Called after a position is confirmed open by the broker.
- `OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason)` -- Called after a position is confirmed closed, with the close reason.
- `OnEnd()` -- Called during normal EA shutdown (not on parameter changes or chart changes).
- `OnDeinit()` -- Called on every EA removal for local cleanup. No I/O or remote calls allowed here.
