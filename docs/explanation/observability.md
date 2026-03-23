# Observability

## Overview

Horizon5 provides observability through two optional integrations (HorizonMonitor, HorizonGateway) and local file-based reporting. The system can run fully standalone with no external dependencies -- integrations enhance visibility but are not required.

## HorizonMonitor

The Monitor integration pushes data to the Horizon API (a Django REST API) for centralized tracking. It implements `IRemoteLogger`, meaning it also receives log entries from the EA's logger system.

Data pushed to the Monitor API includes:

- **Account state**: balance, equity, margin, and metadata -- synced hourly via `SyncAccount()`.
- **Asset and strategy registration**: on startup, each enabled asset and strategy is upserted to the API with deterministic UUIDs.
- **Order events**: order creation, fills, closes, and cancellations are forwarded as HTTP POST requests via the `connector` message bus channel.
- **Heartbeats**: periodic signals indicating the EA is alive.
- **Logs**: error and warning entries forwarded to the API for remote log aggregation.
- **Snapshots**: strategy performance snapshots (statistics, P&L) pushed periodically.

The Monitor service (`HorizonMonitor.mq5`) handles the actual HTTP calls asynchronously, prioritizing order-related endpoints over general telemetry.

## HorizonGateway

The Gateway integration enables remote order management. External systems (such as the Horizon War Room or autonomous agents) can create, modify, and close orders by posting events to the Horizon API, which the Gateway service polls and forwards to the EA.

Supported remote operations:

- `post.order` -- Create a new order on a specific strategy
- `delete.order` -- Close an existing order
- `put.order` -- Modify an order (stop-loss, take-profit)
- `get.orders` -- Query current open orders

Service-level queries (non-trading):

- `get.account.info` -- Return account balance, equity, margin
- `get.assets` / `get.strategies` -- List registered assets and strategies
- `get.ticker` / `get.klines` -- Return market data
- `patch.account.disable` / `patch.account.enable` -- Pause or resume trading remotely

Each event is acknowledged back to the API with a success or error status, closing the request-response loop.

## Deterministic UUIDs

Local objects (account, assets, strategies) are assigned UUIDs generated deterministically from seed strings. Both the EA and the API independently compute the same UUID for a given entity, so there is no need for a registration handshake to exchange IDs. This design:

- Survives EA restarts without re-registration
- Works identically across Monitor and Gateway integrations
- Enables log correlation between the EA and the API

The UUID mapping is logged on startup for verification.

## Horizon War Room

The Horizon War Room is a separate monitoring dashboard that consumes the Horizon API. It provides real-time visibility into account state, strategy performance, and order activity across all connected EAs. The EA itself has no direct dependency on the War Room -- all data flows through the API.

## Local reports

On EA shutdown (or after backtests via `OnTester`), the EA exports several report types:

- **Order history** (CSV/JSON): complete record of all orders with entry/exit prices, P&L, timestamps, and close reasons.
- **Strategy snapshots**: periodic performance statistics per strategy (win rate, profit factor, drawdown).
- **Market snapshots**: price, spread, rolling return, drawdown, and volatility data per asset.
- **Logs**: all log entries collected during the session, exported to file.

Reports are generated per-asset by calling `ExportOrderHistory()`, `ExportStrategySnapshots()`, and `ExportMarketSnapshots()`.

## Standalone mode

When both `EnableHorizonMonitor` and `EnableHorizonGateway` are `false`, or the EA runs in backtesting mode, no external services are needed. Order persistence still works via direct file writes (bypassing the message bus), and all reports are generated locally. This makes the EA fully self-contained for development, testing, and environments without API access.
