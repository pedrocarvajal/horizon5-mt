# Services

All services in the `services/` directory, organized by prefix and responsibility.

## Core Services (SE\*)

| Service      | Path                     | Purpose                                                                                |
| ------------ | ------------------------ | -------------------------------------------------------------------------------------- |
| SEDateTime   | `services/SEDateTime/`   | Provides current time and date utilities for event detection.                          |
| SEDb         | `services/SEDb/`         | File-based key-value persistence layer for local JSON storage.                         |
| SELogger     | `services/SELogger/`     | Structured logging with configurable debug levels and optional file persistence.       |
| SELotSize    | `services/SELotSize/`    | Calculates position size based on equity-at-risk and symbol specifications.            |
| SEMessageBus | `services/SEMessageBus/` | Inter-service communication bus that coordinates service readiness and event dispatch. |
| SEOrderBook  | `services/SEOrderBook/`  | Manages the collection of orders for a strategy, tracking open and pending positions.  |
| SERequest    | `services/SERequest/`    | HTTP request wrapper for communicating with external APIs.                             |
| SEStatistics | `services/SEStatistics/` | Tracks and computes trading performance metrics per strategy.                          |

## Persistence Services (SR\*)

| Service                   | Path                                  | Purpose                                                                  |
| ------------------------- | ------------------------------------- | ------------------------------------------------------------------------ |
| SRPersistenceOfOrders     | `services/SRPersistenceOfOrders/`     | Serializes and deserializes orders to JSON files for crash recovery.     |
| SRPersistenceOfState      | `services/SRPersistenceOfState/`      | Persists strategy state (e.g., indicator values, flags) across restarts. |
| SRPersistenceOfStatistics | `services/SRPersistenceOfStatistics/` | Persists cumulative statistics to survive EA restarts.                   |

## Report Services (SR\*)

| Service                     | Path                                    | Purpose                                                              |
| --------------------------- | --------------------------------------- | -------------------------------------------------------------------- |
| SRReportOfLogs              | `services/SRReportOfLogs/`              | Exports accumulated log entries to CSV files.                        |
| SRReportOfMarketSnapshots   | `services/SRReportOfMarketSnapshots/`   | Exports market data snapshots to CSV during strategy tester runs.    |
| SRReportOfOrderHistory      | `services/SRReportOfOrderHistory/`      | Exports completed order history to CSV during strategy tester runs.  |
| SRReportOfStrategySnapshots | `services/SRReportOfStrategySnapshots/` | Exports strategy state snapshots to CSV during strategy tester runs. |

## Integration Services (SR\*)

| Service                          | Path                                         | Purpose                                                                                     |
| -------------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------- |
| SRImplementationOfHorizonMonitor | `services/SRImplementationOfHorizonMonitor/` | Communicates with the Horizon Monitor API for remote logging, account sync, and heartbeats. |
| SRImplementationOfHorizonGateway | `services/SRImplementationOfHorizonGateway/` | Communicates with the Horizon Gateway API for remote order management and account status.   |

## Order Management (SR\*)

| Service              | Path                             | Purpose                                                                           |
| -------------------- | -------------------------------- | --------------------------------------------------------------------------------- |
| SRRemoteOrderManager | `services/SRRemoteOrderManager/` | Processes order commands received from the Horizon Gateway (open, close, modify). |
