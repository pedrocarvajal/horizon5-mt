# Live Trading Setup

Live trading requires at least one running MT5 service alongside the EA. Optional integrations add remote orchestration.

## Required service

### HorizonPersistence

`HorizonPersistence.mq5` must be running in live trading. It polls the persistence channel on the message bus, deduplicates writes targeting the same path within each polling cycle, and flushes to disk. It also ensures target directories exist and emits queue diagnostics periodically.

Start it by dragging `HorizonPersistence` into the MT5 Navigator panel as a service; it starts automatically with the terminal.

## Optional integrations

Both depend on external backends that live in the private ecosystem — request access via [GitHub](https://github.com/pedrocarvajal) if you intend to use them.

### HorizonMonitor (telemetry)

Pushes account snapshots, orders, heartbeats, and logs outward for centralized observability.

EA inputs:

- `EnableHorizonMonitor = true`
- `HorizonMonitorUrl`, `HorizonMonitorEmail`, `HorizonMonitorPassword`

### HorizonGateway (remote orchestration)

Consumes trading and service events from the backend and forwards them to the EA. The per-asset `SEGateway` dispatches inbound trading events to handlers and ACKs responses back.

EA inputs:

- `EnableHorizonGateway = true`
- `HorizonGatewayUrl`, `HorizonGatewayEmail`, `HorizonGatewayPassword`

Both integrations authenticate on startup via `UpsertAccount()`. If authentication fails, the EA refuses to initialize.

## Service health monitoring

`CheckServiceHealth()` runs every minute against all required services:

- `HorizonPersistence` is always required.
- `HorizonMonitor` is required when Monitor is enabled.
- `HorizonGateway` is required when Gateway is enabled.

If a required service becomes unavailable:

1. The message bus is shut down.
2. `tradingStatus.isPaused = true` with `TRADING_PAUSE_REASON_SERVICES_DOWN`.
3. New positions are not opened; existing positions continue to be managed.

When services recover, the bus reactivates and trading resumes automatically.

## Gateway account status

If Gateway is enabled, the EA fetches the account status on init. A status other than `"active"` pauses trading with `TRADING_PAUSE_REASON_ACCOUNT_INACTIVE`. This lets operators pause the account remotely without restarting the EA.
