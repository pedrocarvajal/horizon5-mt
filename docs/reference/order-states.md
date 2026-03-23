# Order States

Orders in Horizon5 follow a deterministic state machine defined in `enums/EOrderStatuses.mqh`.

## State Machine

```
PENDING ----> OPEN ----> CLOSING ----> CLOSED
   |                        |
   +---> CANCELLED          +---> CANCELLED
```

## States

### PENDING

The order has been created by a strategy signal but has not yet been submitted to the broker. Orders remain in this state while waiting for market conditions to be met (e.g., price reaching `openAtPrice`) or while the market is closed. The order processing loop in `OnTimer` picks up pending orders and attempts execution each cycle.

### OPEN

The broker has confirmed a fill. The order now has a valid `positionId`, `dealId`, `openPrice`, and `openAt` timestamp. The position is actively tracked and exposed to strategy callbacks like `OnOpenOrder`.

### CLOSING

A close signal has been issued (by the strategy, stop-loss, take-profit, or a remote Gateway command) but the broker has not yet confirmed the exit. The order stays in this state until the `OnTradeTransaction` callback processes the closing deal.

### CLOSED

The broker has confirmed the exit. Final values for `closePrice`, `profitInDollars`, `commission`, `swap`, and `closeAt` are recorded. The strategy receives an `OnCloseOrder` callback with the close reason.

### CANCELLED

The order was abandoned before reaching the CLOSED state. This can happen from PENDING (e.g., strategy revokes the signal, market conditions expire) or from CLOSING (e.g., broker rejects the close request, order expires).

## Persistence and Recovery

All order state transitions are serialized to JSON files by `SRPersistenceOfOrders`. On EA restart, the persistence layer deserializes saved orders and restores them into each strategy's `SEOrderBook`. This ensures that open positions are not lost during crashes, VPS reboots, or planned restarts.

## Automatic Queueing

When the market is closed, orders in PENDING state are automatically queued. The order processing loop detects that the symbol is not tradeable and retries on subsequent timer cycles until the market reopens. Retry logic uses `retryCount` and `retryAfter` fields to implement backoff.
