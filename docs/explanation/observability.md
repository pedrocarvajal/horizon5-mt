# Observability

Horizon5 provides two layers of observability: **local reporting** (always available) and **remote integrations** (optional, for the private ecosystem).

## Standalone mode

When the Monitor and Gateway integrations are disabled — or when running in the Strategy Tester — the EA is fully self-contained:

- Order persistence still works (direct file writes in tester; via the persistence service in live).
- Local reports are generated from `OnTester()` / on EA shutdown:
  - **Order history** — per strategy, full record of orders with entry/exit prices, P&L, timestamps, close reasons.
  - **Strategy snapshots** — periodic statistics per strategy (win rate, profit factor, drawdown, NAV).
  - **Market snapshots** — price, spread, rolling return, rolling drawdown, rolling volatility per asset.
  - **Logs** — all log entries collected during the session.
  - **Monitor seed** — Monitor-shaped seed datasets (accounts, assets, strategies, metadata, orders, snapshots) for bootstrapping an external store from backtest output.

This makes the framework usable for development, research, and environments without any backend.

## Remote telemetry — Monitor integration

When enabled, the EA pushes data to a private backend through the Monitor integration. It also implements `IRemoteLogger`, receiving log entries forwarded from the EA's logger.

The backend receives:

- **Account state** — balance, equity, margin, metadata, synced hourly via `SyncAccount()`.
- **Asset and strategy registration** — deterministic UUIDs upserted on startup.
- **Order events** — creation, fills, modifications, closes, cancellations, forwarded as HTTP POST bodies via the `connector` channel.
- **Heartbeats** — liveness signals for the EA and every registered strategy/service.
- **Logs** — error/warning entries forwarded for remote aggregation.
- **Snapshots** — strategy and asset performance snapshots on daily/hourly/event-triggered edges (`ENUM_SNAPSHOT_EVENT`).

The `HorizonMonitor.mq5` service performs the actual HTTP calls, prioritizing order-related endpoints over general telemetry.

## Remote orchestration — Gateway integration

When enabled, the EA consumes events from the same private backend through the Gateway integration. Supported events:

Trading events (routed to order management):

- `post.order` — open a new order on a specific strategy.
- `delete.order` — close an existing order.
- `put.order` — modify an order (SL/TP).
- `get.orders` — query current open orders.

Service events (non-trading):

- `get.account.info` — return account balance, equity, margin.
- `get.assets` / `get.strategies` — return registered entities.
- `get.ticker` / `get.klines` — return market data.
- `patch.account.disable` / `patch.account.enable` — remotely pause or resume trading.

Every event is ACKed back to the backend, closing the request/response loop.

## Deterministic UUIDs

All external correlation uses deterministic UUIDs (see [Portfolio Approach](portfolio-approach.md)). Because the EA and the backend compute the same UUID for a given entity from the same seed, there is no registration handshake and no ID drift across restarts.

The UUID mapping is logged on every init for verification.

## Dashboard

A dashboard that consumes the Monitor backend (the War Room) is part of the private ecosystem. The EA has no direct dependency on it — all data flows through the backend.
