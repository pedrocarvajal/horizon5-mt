# Order States

Orders follow a deterministic state machine defined in `enums/EOrderStatuses.mqh`.

## State machine

```
PENDING ─┬─→ OPEN ──→ CLOSING ──→ CLOSED
         │                     └─→ CANCELLED
         └─→ CANCELLED
```

## States

### `ORDER_STATUS_PENDING`

Created by a strategy signal but not yet live at the broker. Stays here while:

- waiting for the market to reopen,
- waiting for a limit/stop to trigger,
- being retried after a transient send failure (bounded by `MAX_RETRY_COUNT_OPEN`).

`SEOrderBook.ProcessOrders()` picks up pending orders every cycle and attempts submission.

### `ORDER_STATUS_OPEN`

Broker confirmed the fill. The order has a valid `positionId`, `dealId`, `openPrice`, and `openAt`. Strategies receive `OnOpenOrder()`. Further modifications (SL/TP updates) keep the state `OPEN` and fire `OnOrderUpdated()`.

### `ORDER_STATUS_CLOSING`

A close intent was issued (by the strategy, SL/TP, or a remote command) but the broker has not yet confirmed the exit. The order stays here until `OnTradeTransaction` delivers the matching close deal. Failures here are retried (`MAX_RETRY_COUNT_CLOSE`); exhaustion transitions to `CANCELLED`.

### `ORDER_STATUS_CLOSED`

Broker confirmed the exit. `closePrice`, `profitInDollars`, `commission`, `swap`, and `closeAt` are all recorded. Net profit is `profit + commission * 2 + swap`. Strategies receive `OnCloseOrder(order, reason)`.

### `ORDER_STATUS_CANCELLED`

The order was abandoned before `CLOSED`. Possible paths:

- From `PENDING` — signal revoked, pending expired, or retry budget exhausted.
- From `CLOSING` — broker rejected the close request and the retry budget was exhausted.

## Persistence and recovery

Every transition is serialized by `SRPersistenceOfOrders`. In live trading the write goes through the message bus to the Persistence service; in tester mode it writes directly.

On startup, each strategy reloads its order JSON and reconciles open orders against the current MT5 positions (by magic number and position ID). `SRAccountAuditor` cross-checks the resulting view on init and on every new hour, emitting diagnostics when MT5 state diverges from tracked state.

## Market-closed queueing

Orders placed while the market is closed are held with `pendingToOpen = true`. The order book checks market status each cycle; when the market reopens, queued orders are submitted in order.

## Retry budgets

Each transition has an independent retry budget declared as a constant (`MAX_RETRY_COUNT_OPEN`, `MAX_RETRY_COUNT_CANCEL`, `MAX_RETRY_COUNT_CLOSE`, default `3` each). Retries are spaced using `HResolveTransientDeferSeconds.mqh` for transient retcodes. Permanent retcodes transition straight to `CANCELLED`.
