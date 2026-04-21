# Services

Every service in the `services/` directory, grouped by prefix and responsibility.

## Core services (`SE*`)

| Service        | Path                     | Purpose                                                                      |
| -------------- | ------------------------ | ---------------------------------------------------------------------------- |
| `SEDateTime`   | `services/SEDateTime/`   | Broker-aware datetime utilities and broken-down time                         |
| `SEDb`         | `services/SEDb/`         | File-backed key/value store used by strategy state persistence               |
| `SEGateway`    | `services/SEGateway/`    | Per-asset inbound/outbound gateway routing (events, ACKs, notifications)     |
| `SELogger`     | `services/SELogger/`     | Structured logging with configurable debug levels and optional remote sink   |
| `SELotSize`    | `services/SELotSize/`    | Position sizing from equity-at-risk and symbol tick economics                |
| `SEMessageBus` | `services/SEMessageBus/` | Client for the shared-memory DLL message bus (send, poll, ACK, health, wait) |
| `SEOrderBook`  | `services/SEOrderBook/`  | Per-strategy order lifecycle (place, modify, close, cancel, retry, restore)  |
| `SERequest`    | `services/SERequest/`    | HTTP request wrapper used by the integration resources                       |
| `SEStatistics` | `services/SEStatistics/` | Per-strategy statistics, NAV, quality metric, daily snapshots                |

## Persistence services (`SR*`)

| Service                     | Path                                  | Purpose                                                   |
| --------------------------- | ------------------------------------- | --------------------------------------------------------- |
| `SRPersistenceOfOrders`     | `services/SRPersistenceOfOrders/`     | Serializes/deserializes orders as JSON for crash recovery |
| `SRPersistenceOfState`      | `services/SRPersistenceOfState/`      | Persists strategy-defined key/value state across restarts |
| `SRPersistenceOfStatistics` | `services/SRPersistenceOfStatistics/` | Persists cumulative statistics across restarts            |

## Report services (`SR*`)

| Service                       | Path                                    | Purpose                                                             |
| ----------------------------- | --------------------------------------- | ------------------------------------------------------------------- |
| `SRReportOfLogs`              | `services/SRReportOfLogs/`              | Exports accumulated log entries to file                             |
| `SRReportOfMarketSnapshots`   | `services/SRReportOfMarketSnapshots/`   | Exports per-asset market snapshots                                  |
| `SRReportOfOrderHistory`      | `services/SRReportOfOrderHistory/`      | Exports per-strategy order history                                  |
| `SRReportOfStrategySnapshots` | `services/SRReportOfStrategySnapshots/` | Exports per-strategy statistics snapshots                           |
| `SRReportOfMonitorSeed`       | `services/SRReportOfMonitorSeed/`       | Exports Monitor-shaped seed datasets (accounts/assets/strategies/…) |

## Integration services (`SR*`)

| Service                            | Path                                         | Purpose                                                                       |
| ---------------------------------- | -------------------------------------------- | ----------------------------------------------------------------------------- |
| `SRImplementationOfHorizonMonitor` | `services/SRImplementationOfHorizonMonitor/` | EA-side client for the Monitor integration (telemetry, snapshots, heartbeats) |
| `SRImplementationOfHorizonGateway` | `services/SRImplementationOfHorizonGateway/` | EA-side client for the Gateway integration (account status, inbound dispatch) |

## Reconciliation (`SR*`)

| Service            | Path                         | Purpose                                                                            |
| ------------------ | ---------------------------- | ---------------------------------------------------------------------------------- |
| `SRAccountAuditor` | `services/SRAccountAuditor/` | Reconciles MT5 positions, pending orders, and tracked orders on startup and hourly |

## Standalone services (`.mq5`)

Independent MT5 service scripts communicating with the EA through the message bus. Detailed in [Explanation > Service Architecture](../explanation/service-architecture.md).

| Script                   | Registers as             | Role                                |
| ------------------------ | ------------------------ | ----------------------------------- |
| `HorizonPersistence.mq5` | `MB_SERVICE_PERSISTENCE` | Async file I/O                      |
| `HorizonMonitor.mq5`     | `MB_SERVICE_MONITOR`     | Outbound telemetry relay            |
| `HorizonGateway.mq5`     | `MB_SERVICE_GATEWAY`     | Inbound trading/service event relay |
