# Design Decisions

## Equal-weight allocation over optimization-based allocation

Strategies and assets receive equal capital shares. No prediction is made about which will outperform. This avoids overfitting to historical performance, shrinks the parameter space, and keeps the system robust to regime changes. The portfolio's edge comes from diversification across uncorrelated strategies, not from optimized weighting.

## Services as separate `.mq5` files over in-process threads

MT5 does not support multi-threading inside a single EA. The only way to run concurrent work is through independent MT5 services. Each service (`HorizonPersistence`, `HorizonGateway`, `HorizonMonitor`) is a standalone `.mq5` file with its own `OnStart()` loop. Services communicate with the EA exclusively through the shared-memory message bus — no shared variables, no direct calls, no invisible coupling.

## Message bus over direct HTTP calls

HTTP calls in MQL5 are synchronous and can block for seconds on timeouts. Routing all I/O through a DLL-backed bus with fire-and-forget publishing keeps the EA's `OnTimer` and `OnTradeTransaction` fast. The bus also provides sequence-based ACKing, per-path deduplication (in Persistence), priority ordering (order endpoints first in Monitor), and queue diagnostics.

## JSON file persistence over database

MT5 has no native database access. File I/O is the only local persistence mechanism. Horizon5 serializes order state, statistics, and strategy key/value state as JSON — human-readable, easy to inspect, straightforward to reload on restart. The Persistence service handles writes asynchronously and deduplicates rapid updates to the same path, keeping disk I/O bounded.

## Deterministic identifiers over server-assigned IDs

Magic numbers (DJB2 of `symbol_assetName_strategyName`, mod 1B) and UUIDs (seeded hash formatted as UUID v5) are computed locally from stable inputs. There are no registration round-trips, identifiers survive restarts, and the EA and any backend independently compute matching IDs. The EA validates magic-number uniqueness at init and refuses to run on collision.

## Primed-bar events over wall-clock ticks

Bar events (`OnStartMinute`, `OnStartHour`, `OnStartDay`) fire on actual bar opens for each asset's symbol. This decouples strategy evaluation from the chart the EA happens to be attached to and from broker tick cadence. Wall-clock edges are still used, but only for portfolio-wide maintenance (Monitor sync, service health, auditing).

## Equity-at-risk sizing over fixed lot

Lot size is derived from equity-at-risk and stop-loss distance: `lots = (nav * equityAtRisk%) / (stopDistance * tickValue / tickSize)`. Optionally compounded on current NAV. This scales naturally with account size and normalizes risk across instruments with different tick economics. Fixed-lot alternatives either under-utilize capital on large accounts or over-leverage small ones.

## Typed trading pause reasons over a single boolean

`ETradingPauseReason` carries the reason for every pause (services down, account inactive, remote request, manual close, etc.). Resume logic is reason-aware — only non-critical pauses clear at the start of a new day; service-outage pauses clear on recovery; account-inactive pauses clear when the backend reports active again. Encoding reason as data, not control flow, keeps the state machine auditable.

## Strategies as open extension, framework as closed core

The framework is deliberately opinionated about infrastructure (services, events, lifecycle, persistence, identity) and deliberately unopinionated about trading logic. Strategies subclass `SEStrategy`, override the hooks they need, and inherit everything else. There is no prescribed methodology for how a strategy makes decisions — that space is yours.
