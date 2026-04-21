# Order Lifecycle

## State machine

```
PENDING ─┬─→ OPEN ──→ CLOSING ──→ CLOSED
         │                     └─→ CANCELLED
         └─→ CANCELLED
```

Defined in `enums/EOrderStatuses.mqh`; full reference in [Reference > Order States](../reference/order-states.md).

## Signal generation

Strategies produce signals inside their lifecycle hooks — most commonly `OnStartHour()`, though any event (`OnTick`, `OnStartDay`, `OnStartMinute`) is fair game. When a strategy decides to open a position it constructs an `EOrder` with:

- side (BUY/SELL),
- volume (from `SELotSize` using equity-at-risk and stop distance),
- stop-loss and take-profit prices,
- signal price and timestamp,
- a UUID as the order ID,
- the strategy's magic number and symbol,
- status `ORDER_STATUS_PENDING`.

## Placement

The strategy hands the order to its `SEOrderBook` via `PlaceOrder()`:

1. The book appends it to its internal `orders[]`.
2. If the market is closed, it is queued (`pendingToOpen = true`) and will be submitted when the market reopens.
3. Otherwise the book submits it to MT5 through `ATrade` (a `CTrade` adapter).
4. The MT5 order ticket is recorded on the `EOrder` for later matching.
5. The strategy receives `OnPendingOrderPlaced(order)`.

Transient broker errors are retried up to `MAX_RETRY_COUNT_OPEN`; permanent errors transition to `CANCELLED`.

## Fill (PENDING → OPEN)

MT5 fires `OnTradeTransaction` with `TRADE_TRANSACTION_DEAL_ADD` + `DEAL_ENTRY_IN`. The EA:

1. Reads the deal price from history.
2. Walks assets and calls `HandleDealOpen()` until one claims the order by MT5 order ticket.
3. The matching strategy updates the `EOrder`: open price, deal ID, position ID, and status → `ORDER_STATUS_OPEN`.
4. The strategy receives `OnOpenOrder(order)`.

If a fill arrives for an order already in `CANCELLED`, the book treats it as an **orphan fill** and immediately closes the position.

## Monitoring

While open, the strategy checks exit conditions on its normal hooks — strategy-specific signals, time exits, or broker-side SL/TP hits (also observed via `OnTradeTransaction`). Modifications (SL/TP updates) flow through the book and fire `OnOrderUpdated(order)`.

## Close (OPEN → CLOSING → CLOSED)

When the strategy chooses to close:

1. The order transitions to `ORDER_STATUS_CLOSING` with `pendingToClose = true`.
2. `SEOrderBook.ProcessOrders()` detects pending closes and submits them through `ATrade`.
3. On broker confirmation, `OnTradeTransaction` fires with `DEAL_ENTRY_OUT`. The EA extracts profit, commission, swap, computes net P&L (`profit + commission * 2 + swap`), and routes to the owning asset/strategy.
4. The order transitions to `ORDER_STATUS_CLOSED` with final P&L; the strategy receives `OnCloseOrder(order, reason)`.

Broker SL/TP hits follow the same close path, with `DEAL_REASON` set to `DEAL_REASON_SL` or `DEAL_REASON_TP`.

## Cancellation

If an order is cancelled or expires before fill (`TRADE_TRANSACTION_HISTORY_ADD` with `ORDER_STATE_CANCELED` / `ORDER_STATE_EXPIRED`), the EA calls `HandleOrderCancellation()` on each asset. The matching strategy transitions the order to `ORDER_STATUS_CANCELLED` and fires `OnCancelOrder(order)`.

Each lifecycle operation has its own retry budget (`MAX_RETRY_COUNT_OPEN`, `MAX_RETRY_COUNT_CANCEL`, `MAX_RETRY_COUNT_CLOSE`, default 3). Transient retcodes are deferred via `HResolveTransientDeferSeconds.mqh`; budget exhaustion transitions the order to `CANCELLED`.

## Persistence

Every state change triggers JSON serialization via `SRPersistenceOfOrders`. In live trading the write is published to the persistence channel and handled asynchronously by `HorizonPersistence`; in tester mode it writes directly. The JSON file contains the full orders array per strategy — enough to rebuild state on restart.

## Recovery on restart

In live mode, each strategy's `SRPersistenceOfOrders` loads its order JSON on init. Open orders are reconciled against current MT5 positions by magic number and position ID. `SRAccountAuditor` then cross-checks MT5 positions, pending orders, and tracked orders and logs any divergences. The auditor re-runs at the start of every hour.

## Market-closed queueing

Orders placed while the market is closed are held with `pendingToOpen = true`. `SEOrderBook.ProcessOrders()` inspects market status every cycle; when the market reopens, queued orders submit in order.
