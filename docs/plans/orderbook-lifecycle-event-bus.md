# OrderBook Lifecycle Event Bus

Status: proposed
Owner: unassigned
Related: `services/SEOrderBook/`

## Context

The `SEOrderBook` refactor (April 2026) split the monolithic class into a facade + `components/` (Opener, Closer, Canceller, Modifier, Processor, Restorer, Purger) + `validators/Validator.mqh` + pure `helpers/`. During the cleanup we deleted three dead counters (`closedOrderCount`, `todayOrderCount`) and derived `activeOrderCount` from the `orders[]` array instead of maintaining it manually. This removed the back-channel calls `orderBook.OnOrderClosed()` / `orderBook.OnOrderCancelled()` that `Strategy.mqh` used to perform after receiving listener callbacks.

The removal raised a valid architectural question: **should the OrderBook receive an explicit event for every lifecycle transition (open, close, cancel, modify) through a single unified entry point?**

Today the answer is "every transition already goes through the OrderBook, but via different methods depending on origin":

| Origin                    | Entry point today                                                          |
| ------------------------- | -------------------------------------------------------------------------- |
| Broker confirms fill      | `orderBook.OnOpenOrder(order, result)` (called by `Asset.HandleDealOpen`)  |
| Broker confirms close     | `orderBook.OnCloseOrder(order, ...)` (called by `Asset.HandleDealClose`)   |
| Broker confirms cancel    | `orderBook.CancelOrder(order)` (called by `Asset.HandleOrderCancellation`) |
| Strategy places order     | `orderBook.PlaceOrder(...)`                                                |
| Strategy closes / cancels | `orderBook.CloseOrder(order)`                                              |
| Strategy modifies SL/TP   | `orderBook.ModifyStopLoss(...)` / etc.                                     |

Every path mutates the `orders[]` array state, but there is no single point where a component can react to "any state transition". Side effects (persistence save, listener notify, metrics) are hand-wired at each callsite and easy to forget.

On top of that, `Horizon.mq5::OnTradeTransaction` only routes three transaction types today:

- `TRADE_TRANSACTION_HISTORY_ADD` (cancel / expire)
- `TRADE_TRANSACTION_DEAL_ADD` with `DEAL_ENTRY_IN` (fill)
- `TRADE_TRANSACTION_DEAL_ADD` with `DEAL_ENTRY_OUT` (close)

Every other `MqlTradeTransaction` variant (`ORDER_ADD`, `ORDER_UPDATE`, `ORDER_DELETE`, `POSITION`, `DEAL_UPDATE`, `DEAL_DELETE`, `DEAL_ENTRY_INOUT`, `DEAL_ENTRY_OUT_BY`, `REQUEST`) is silently dropped. An SL moved from the MT5 client, a pending order's price edited manually, a position reversal, or a close-by operation never reach the OrderBook. Its in-memory `orders[]` state therefore drifts from the broker's truth, and `SRAccountAuditor` catches it only as a generic count mismatch, not as a semantic event.

## What

Introduce an internal lifecycle event bus inside `SEOrderBook` **and** close every hole in the broker -> `Asset` -> `OrderBook` event chain.

### Rule 1: every `OnTradeTransaction` event reaches `Asset`

`Horizon.OnTradeTransaction` must route **every** transaction type that can affect an order we track. No silent drops. `Asset` is the single fan-out point that forwards the event to the right strategy's `SEOrderBook`. This keeps `Asset` (and therefore all its strategies) always in sync with the broker's view.

Transaction types to route (non-exhaustive, based on MQL5 `ENUM_TRADE_TRANSACTION_TYPE`):

- `TRADE_TRANSACTION_ORDER_ADD`
- `TRADE_TRANSACTION_ORDER_UPDATE`
- `TRADE_TRANSACTION_ORDER_DELETE`
- `TRADE_TRANSACTION_DEAL_ADD` (entry IN / OUT / INOUT / OUT_BY)
- `TRADE_TRANSACTION_DEAL_UPDATE`
- `TRADE_TRANSACTION_DEAL_DELETE`
- `TRADE_TRANSACTION_HISTORY_ADD` (cancellation / expiration)
- `TRADE_TRANSACTION_POSITION` (SL / TP change on open position)

Each gets a dedicated `Asset.Handle*` method that finds the owning strategy and forwards to its `SEOrderBook`.

### Rule 2: every internal mutation also reaches the OrderBook

Anything that `SEOrderBook` or its components originate (PlaceOrder, Open, Close, Cancel, Modify, Restore, Purge) must dispatch the matching lifecycle event through the bus. No component mutates `EOrder` state silently.

### Rule 3: OrderBook exposes a complete `On*` surface

The `SEOrderBook` facade must have an entry point for **every lifecycle case**, regardless of origin. Naming is `On<Event>`; body delegates to the bus:

| Facade entry point         | Trigger                                                  |
| -------------------------- | -------------------------------------------------------- |
| `OnOrderPlaced`            | Strategy / `PlaceOrder` creates a new order locally      |
| `OnPendingOrderRegistered` | Broker confirmed a pending order exists (`ORDER_ADD`)    |
| `OnPendingOrderUpdated`    | Broker confirmed pending price / SL / TP change          |
| `OnPendingOrderRemoved`    | Broker removed a pending order (`ORDER_DELETE` non-fill) |
| `OnOrderOpened`            | Deal IN: pending filled or market order executed         |
| `OnPositionModified`       | Broker confirmed SL / TP change on open position         |
| `OnOrderClosing`           | Close / cancel request sent, waiting for broker confirm  |
| `OnOrderClosed`            | Deal OUT / OUT_BY / INOUT: position closed               |
| `OnOrderCancelled`         | `HISTORY_ADD` with state CANCELED / EXPIRED              |
| `OnOrderModified`          | Local SL / TP / price change requested by strategy       |
| `OnOrderRestored`          | Order reloaded from persistence at startup               |
| `OnOrderPurged`            | Order removed from memory by purger                      |

Each of these `On*` methods translates to one `ENUM_ORDER_LIFECYCLE_EVENT` and calls `bus.Dispatch(order, event)`.

### Implementation steps

1. Define enum `ENUM_ORDER_LIFECYCLE_EVENT` with one value per row in the table above.
2. Create `OrderEventBus` component: holds subscriber list, exposes `Dispatch(order, event)` and `Subscribe(handler)`.
3. Create subscribers for existing side effects (persistence, listener forwarding, metrics).
4. Refactor `SEOrderBook` facade to expose the full `On*` API from the table above. Each method is a one-liner that calls the bus.
5. Refactor components (`Opener`, `Closer`, `Canceller`, `Modifier`) to dispatch events instead of calling `PersistOrder` / `listener.On*` directly.
6. Extend `Horizon.OnTradeTransaction` to route every relevant transaction type to `Asset`.
7. Extend `Asset.mqh` with one `Handle*` method per transaction type, forwarding to the owning strategy's `SEOrderBook.On*`.
8. Close the loop: every broker transaction and every internal mutation flows through the bus, with no bypass.

## Why

- **No broker blind spots**: every `OnTradeTransaction` event reaches `Asset` and the matching `OrderBook`. `Asset` and all its strategies stay perfectly in sync with the broker.
- **No internal blind spots**: every component mutation dispatches through the bus, so persistence, listener, metrics, and any future subscriber see the full timeline.
- **Single choke point for side effects**: adding a new subscriber (auditor, metrics, replication) becomes one new handler, not edits scattered across 7 components.
- **Impossible to forget persistence**: if the dispatcher always persists, no handler can leak state by forgetting to save.
- **Unlocks event sourcing**: the dispatcher is the obvious place to append an event log for debugging / replay.
- **Simpler components**: Opener/Closer/Canceller shrink because cross-cutting concerns (persist, notify) move out.
- **Clearer mental model**: every state transition visible at one point; easier to reason about and test.
- **Auditability**: `SRAccountAuditor` can rely on the bus as a semantic event stream, not just periodic count comparisons.

## Expected outcome

```
services/SEOrderBook/
|- SEOrderBook.mqh                     (facade, owns orders[] + bus)
|- enums/
|  \- EOrderLifecycleEvent.mqh         (new)
|- components/
|  |- OrderEventBus.mqh                (new: dispatch + subscribe)
|  |- OrderOpener.mqh                  (no direct Persist / listener calls)
|  |- OrderCloser.mqh                  (idem)
|  |- OrderCanceller.mqh               (idem)
|  |- OrderModifier.mqh                (idem)
|  |- OrderProcessor.mqh               (unchanged)
|  |- OrderRestorer.mqh                (unchanged)
|  \- OrderPurger.mqh                  (unchanged)
|- subscribers/                        (new)
|  |- SPersistenceSubscriber.mqh       (saves to SRPersistenceOfOrders)
|  \- SListenerSubscriber.mqh          (forwards to IStrategy callbacks)
|- validators/
|  \- Validator.mqh
\- helpers/
   \- ...
```

- `SEOrderBook` public API is **extended** (new `On*` methods per lifecycle case) but existing methods remain backward compatible; `Strategy.mqh` needs no changes.
- `Asset.mqh` gains one `Handle*` method per `OnTradeTransaction` type and forwards to the target `SEOrderBook.On*`.
- `Horizon.OnTradeTransaction` routes every relevant transaction type; no more silent drops.
- Every order state transition (broker-originated and internal) flows through `bus.Dispatch(order, event)`.
- Persistence and listener notifications happen as bus subscribers, not as inline calls.

## System diagram

```
  MT5 terminal                     Strategy code
  ------------                     -------------
       |                                 |
       |  MqlTradeTransaction            | PlaceOrder / CloseOrder /
       |  (every type)                   | CancelAll / ModifyStopLoss ...
       v                                 |
+-----------------+                      |
| Horizon.mq5     |                      |
| OnTradeTransac. |                      |
|  full switch    |                      |
+--------+--------+                      |
         |                               |
         |  route by (type, entry, state)|
         v                               |
+--------------------+                   |
|     Asset.mqh      |                   |
|  Handle*Order*     |                   |
|  Handle*Deal*      |                   |
|  Handle*Position*  |                   |
+----+----------+----+                   |
     |          |                        |
     |          |  IStrategy listener    |
     |          +----------------------> Strategy
     |                                   |
     |  OrderBook.On*                    |  OrderBook.On* (internal path)
     v                                   v
+------------------------------------------------------------------+
|                          SEOrderBook                             |
|  +-----------------------------------------------------------+   |
|  | OnOrderPlaced / OnOrderOpened / OnOrderFilled /           |   |
|  | OnOrderChanged / OnOrderRemoved / OnOrderClosing /        |   |
|  | OnOrderClosed / OnOrderClosedByOpposite /                 |   |
|  | OnOrderCancelled / OnOrderExpired / OnOrderModified /     |   |
|  | OnPositionModified / OnPositionReversed /                 |   |
|  | OnDealUpdated / OnDealDeleted                             |   |
|  +------+----------------------------------------------+-----+   |
|         |                                              |         |
|         |  mutate order state                          |         |
|         v                                              |         |
|  +---------+   +---------+   +-----------+   +-----------+       |
|  | Opener  |   | Closer  |   | Canceller |   | Modifier  |       |
|  +----+----+   +----+----+   +-----+-----+   +-----+-----+       |
|       |             |              |               |             |
|       +-------------+------+-------+---------------+             |
|                            v                                     |
|                 +---------------------+                          |
|                 |   OrderEventBus     |                          |
|                 |  Dispatch(order, e) |                          |
|                 +----------+----------+                          |
|                            |                                     |
|          +-----------------+-----------------+                   |
|          v                                   v                   |
|  +----------------+                  +----------------+          |
|  |  Persistence   |                  |    Listener    |          |
|  |  Subscriber    |                  |   Subscriber   |          |
|  +-------+--------+                  +--------+-------+          |
+----------|------------------------------------|------------------+
           v                                    v
   SRPersistenceOfOrders                    IStrategy
    (SaveOrder per event)              (OnOpenOrder, OnCloseOrder,
                                        OnCancelOrder, OnOrderUpdated,
                                        OnPendingOrderPlaced,
                                        OnOrderModified, ...)
```

## Non-goals

- Not a breaking API change. Existing public methods of `SEOrderBook` keep their signatures; the new `On*` methods are additive and optional for callers that don't need them.
- Not an async / queued bus. `Dispatch` is synchronous, in-process, deterministic.
- Not reactive / pub-sub across services. Scope is strictly inside `SEOrderBook`.
- Not a replacement for `SRAccountAuditor`. The auditor keeps its periodic reconciliation role; the bus gives it a richer signal to react to.

## Open questions

- Should `ModifyStopLoss` etc. emit `ORDER_MODIFIED` even when the order is still pending (no broker call made)? Leaning yes for consistency.
- Should `FinalizeCancelled` become a subscriber reaction to `ORDER_CANCELLED` instead of a helper called from Opener/Canceller? Possibly cleaner.
- Is `OrderEventBus` a component field inside the facade, or a free singleton file-scope object? Leaning field.
- `IStrategy` listener is missing callbacks for several new cases (`OnOrderModified`, `OnPositionReversed`, `OnOrderExpired`, `OnOrderClosedByOpposite`). They must be added to the interface or collapsed into a generic `OnOrderEvent(order, event)` for callers that don't need granularity.
- Some `OnTradeTransaction` variants (e.g. `TRADE_TRANSACTION_REQUEST`) have no meaningful OrderBook mapping and should be logged only. Document which ones are intentionally no-ops.
- Should we add an integration test (or runtime invariant check) that asserts every `MqlTradeTransaction` reaching `OnTradeTransaction` is routed, so silent drops are caught immediately?
