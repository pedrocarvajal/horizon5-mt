# Services

Every service in the `services/` directory, grouped by prefix and responsibility.

## Core services (`SE*`)

| Service        | Path                     | Purpose                                                                             |
| -------------- | ------------------------ | ----------------------------------------------------------------------------------- |
| `SEDateTime`   | `services/SEDateTime/`   | Broker-aware datetime utilities and broken-down time                                |
| `SEDb`         | `services/SEDb/`         | JSON document store in pure MQL5 (MT5 Common Files) backing persistence and reports |
| `SELogger`     | `services/SELogger/`     | Structured logging with configurable debug levels                                   |
| `SELotSize`    | `services/SELotSize/`    | Position sizing from equity-at-risk and symbol tick economics                       |
| `SEOrderBook`  | `services/SEOrderBook/`  | Per-strategy order lifecycle (place, modify, close, cancel, retry, restore)         |
| `SEStatistics` | `services/SEStatistics/` | Per-strategy statistics, NAV, quality metric, daily snapshots                       |

## Persistence services (`SR*`)

| Service                     | Path                                  | Purpose                                                   |
| --------------------------- | ------------------------------------- | --------------------------------------------------------- |
| `SRPersistenceOfOrders`     | `services/SRPersistenceOfOrders/`     | Serializes/deserializes orders as JSON for crash recovery |
| `SRPersistenceOfState`      | `services/SRPersistenceOfState/`      | Persists strategy-defined key/value state across restarts |
| `SRPersistenceOfStatistics` | `services/SRPersistenceOfStatistics/` | Persists cumulative statistics across restarts            |

## Report services (`SR*`)

| Service                       | Path                                    | Purpose                                   |
| ----------------------------- | --------------------------------------- | ----------------------------------------- |
| `SRReportOfLogs`              | `services/SRReportOfLogs/`              | Exports accumulated log entries to file   |
| `SRReportOfMarketSnapshots`   | `services/SRReportOfMarketSnapshots/`   | Exports per-asset market snapshots        |
| `SRReportOfOrderHistory`      | `services/SRReportOfOrderHistory/`      | Exports per-strategy order history        |
| `SRReportOfStrategySnapshots` | `services/SRReportOfStrategySnapshots/` | Exports per-strategy statistics snapshots |

## Reconciliation (`SR*`)

| Service            | Path                         | Purpose                                                                            |
| ------------------ | ---------------------------- | ---------------------------------------------------------------------------------- |
| `SRAccountAuditor` | `services/SRAccountAuditor/` | Reconciles MT5 positions, pending orders, and tracked orders on startup and hourly |
