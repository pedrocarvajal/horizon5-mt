# Order Lifecycle

## Order statuses

An order moves through these states (defined in `EOrderStatuses.mqh`):

```
PENDING -> OPEN -> CLOSING -> CLOSED
                           \-> CANCELLED
```

| Status                   | Meaning                                                          |
| ------------------------ | ---------------------------------------------------------------- |
| `ORDER_STATUS_PENDING`   | Signal generated, order created but not yet filled by the broker |
| `ORDER_STATUS_OPEN`      | Broker confirmed entry (DEAL_ENTRY_IN received)                  |
| `ORDER_STATUS_CLOSING`   | Close request sent to broker, awaiting confirmation              |
| `ORDER_STATUS_CLOSED`    | Broker confirmed exit (DEAL_ENTRY_OUT received)                  |
| `ORDER_STATUS_CANCELLED` | Order was cancelled or expired before fill                       |

## Signal generation

Strategies generate trading signals during their event callbacks -- typically `OnStartHour()`, though any event (`OnTick`, `OnStartDay`, `OnStartMinute`) can trigger a signal depending on the strategy's timeframe.

When a strategy decides to open a position, it creates an `EOrder` entity with:

- Side (BUY or SELL)
- Volume (calculated by `SELotSize` based on equity-at-risk and stop-loss distance)
- Stop-loss and take-profit prices
- Signal price and timestamp
- Status set to `ORDER_STATUS_PENDING`
- A UUID as the order ID
- The strategy's magic number and symbol

## Order placement

The strategy calls `PlaceOrder()` on its `SEOrderBook`, which:

1. Adds the order to its internal `orders[]` array.
2. Checks if the market is open. If closed, the order is queued (`pendingToOpen = true`) and will be sent when the market reopens.
3. When the market is open, sends the order to MT5 via the `ATrade` adapter (a wrapper around the standard `CTrade` class).
4. Records the MT5 order ID on the `EOrder` for later matching.
5. Notifies the strategy listener via `notifyOrderPlaced()`.

## Order fill (PENDING -> OPEN)

When MT5 confirms a fill, the `OnTradeTransaction` callback fires with `TRADE_TRANSACTION_DEAL_ADD` and `DEAL_ENTRY_IN`. The EA's `HandleDealOpenTransaction()`:

1. Extracts the deal price from the deal history.
2. Iterates through all assets calling `HandleDealOpen()` until one claims the order by matching the MT5 order ID.
3. The matching strategy updates the `EOrder`: sets the open price, deal ID, position ID, and transitions status to `ORDER_STATUS_OPEN`.

## Position monitoring

While an order is open, the strategy monitors exit conditions on each relevant event (tick, hour, etc.). Conditions include:

- Strategy-specific exit signals
- Time-based exits
- The broker hitting the SL or TP (detected via `OnTradeTransaction`)

## Order close (OPEN -> CLOSING -> CLOSED)

When the strategy decides to close:

1. It sets the order status to `ORDER_STATUS_CLOSING` and marks `pendingToClose = true`.
2. `SEOrderBook.ProcessOrders()` detects pending closes and sends a close request via `ATrade`.
3. On success, `OnTradeTransaction` fires with `DEAL_ENTRY_OUT`. The EA's `HandleDealCloseTransaction()` extracts profit, commission, and swap, computes net profit (`profit + commission * 2 + swap`), and routes to the matching asset/strategy.
4. The strategy updates the order to `ORDER_STATUS_CLOSED` with final P&L data.

For SL/TP hits, the broker closes the position directly. The EA detects this via `OnTradeTransaction` with a `DEAL_REASON` of SL or TP and follows the same close flow.

## Order cancellation

If an order is cancelled or expires before filling (detected via `TRADE_TRANSACTION_HISTORY_ADD` with `ORDER_STATE_CANCELED` or `ORDER_STATE_EXPIRED`), the EA calls `HandleOrderCancellation()` on each asset. The matching strategy transitions the order to `ORDER_STATUS_CANCELLED`. Each lifecycle operation has its own retry budget (`MAX_RETRY_COUNT_OPEN`, `MAX_RETRY_COUNT_CANCEL`, `MAX_RETRY_COUNT_CLOSE`, each defaulting to 3) -- if a send fails, the order can be retried on the next processing cycle before being cancelled.

## Persistence

Every order state change triggers a JSON serialization via `SRPersistenceOfOrders`. In live trading, the write request is sent to the `persistence` message bus channel, where `HorizonPersistence` handles the actual file I/O asynchronously. In backtesting, writes go directly to disk.

The JSON file contains the full array of orders for each strategy, enabling complete state reconstruction on restart.

## Recovery on restart

When the EA initializes in live mode, each strategy's `SRPersistenceOfOrders` loads its order JSON file. Open orders are matched against current MT5 positions by magic number and position ID. The EA logs an order summary showing MT5 positions, pending orders, and tracked orders to verify consistency.

## Market-closed queueing

Orders placed when the market is closed are held with `pendingToOpen = true`. The `SEOrderBook.ProcessOrders()` method checks market status on each call. When the market reopens, queued orders are submitted to MT5 in sequence.
