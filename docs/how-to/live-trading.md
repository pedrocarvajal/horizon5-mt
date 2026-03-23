# Live Trading Setup

## Required services

### HorizonPersistence (mandatory)

`HorizonPersistence.mq5` is a MetaTrader 5 service that must be running alongside the EA. It handles all file I/O (order state, statistics, strategy state) via a message bus, offloading disk writes from the EA's main thread.

The service polls the persistence channel on the message bus, deduplicates writes to the same file path, and flushes to disk. It logs queue diagnostics every 5 minutes.

To start it: add `HorizonPersistence` as a service in MetaTrader 5's Navigator panel. It starts automatically when the terminal launches.

## Optional integrations

### HorizonMonitor (observability)

Sends order updates, account snapshots, and log entries to the Horizon API for the War Room dashboard.

Configure in EA inputs:

- `EnableHorizonIntegration` = true
- `HorizonMonitorUrl` = base URL of the Horizon API
- `HorizonMonitorEmail` = account email
- `HorizonMonitorPassword` = account password

### HorizonGateway (remote order management)

Enables remote order creation and management through the Horizon API. The Gateway strategy in each asset receives orders from this channel.

Configure in EA inputs:

- `HorizonGatewayUrl` = base URL of the Gateway API
- `HorizonGatewayEmail` = account email
- `HorizonGatewayPassword` = account password

Both Monitor and Gateway authenticate on startup by calling `UpsertAccount()`. If authentication fails, the EA will not initialize.

## Message bus health monitoring

The EA continuously monitors all required services through `CheckServiceHealth()`:

- **HorizonPersistence** is always required.
- **HorizonMonitor** is required only when `EnableHorizonIntegration` is true and Monitor is configured.
- **HorizonGateway** is required only when Gateway is configured.

If any required service stops responding:

1. The message bus is shut down.
2. `tradingStatus.isPaused` is set to `true` with reason `TRADING_PAUSE_REASON_SERVICES_DOWN`.
3. The EA stops opening new positions until services recover.

When services come back online, the EA automatically resumes trading.

## Gateway account status

On startup, if HorizonGateway is enabled, the EA fetches the account status. If the status is not `"active"`, trading is paused with reason `TRADING_PAUSE_REASON_ACCOUNT_INACTIVE`. This allows remote account suspension without restarting the EA.
