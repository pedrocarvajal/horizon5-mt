# Design Decisions

## Equal-weight allocation over optimization-based allocation

Strategies and assets receive equal capital shares. No prediction is made about which will outperform. This avoids overfitting to historical performance, shrinks the parameter space, and keeps the system robust to regime changes. The portfolio's edge comes from diversification across uncorrelated strategies, not from optimized weighting.

## JSON file persistence over database

MT5 has no native database access. File I/O is the only local persistence mechanism. Horizon5 serializes order state, statistics, and strategy key/value state as JSON — human-readable, easy to inspect, straightforward to reload on restart. Writes go through `SEDb`, a small JSON document store implemented in pure MQL5 (no DLL), and run only in live trading.

## Deterministic identifiers over server-assigned IDs

Magic numbers (DJB2 of `symbol_assetName_strategyName`, mod 1B) are computed locally from stable inputs. There are no registration round-trips and identifiers survive restarts. The EA validates magic-number uniqueness at init and refuses to run on collision.

## Primed-bar events over wall-clock ticks

Bar events (`OnStartMinute`, `OnStartHour`, `OnStartDay`) fire on actual bar opens for each asset's symbol. This decouples strategy evaluation from the chart the EA happens to be attached to and from broker tick cadence. Wall-clock edges are still used, but only for portfolio-wide maintenance (daily pause reset, hourly auditing).

## Equity-at-risk sizing over fixed lot

Lot size is derived from equity-at-risk and stop-loss distance: `lots = (nav * equityAtRisk%) / (stopDistance * tickValue / tickSize)`. Optionally compounded on current NAV. This scales naturally with account size and normalizes risk across instruments with different tick economics. Fixed-lot alternatives either under-utilize capital on large accounts or over-leverage small ones.

## Trading pause scoped to the asset

A manual intervention on one symbol says nothing about the others, so each asset owns an `ETradingStatus` shared with its strategies and their order books. A manual close or a pending order cancelled outside the EA pauses only that asset: its pending orders are cancelled and new entries are blocked until the start of the next day, while its open positions keep their stops.

## Strategies as open extension, framework as closed core

The framework is deliberately opinionated about infrastructure (services, events, lifecycle, persistence, identity) and deliberately unopinionated about trading logic. Strategies subclass `SEStrategy`, override the hooks they need, and inherit everything else. There is no prescribed methodology for how a strategy makes decisions — that space is yours.
