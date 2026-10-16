# Project Structure

```
Horizon5/
|-- Horizon.mq5                  Main Expert Advisor (portfolio orchestrator)
|
|-- adapters/                    Thin wrappers over MT5 subsystems
|   |-- ATrade.mqh               Trade execution adapter wrapping CTrade
|
|-- assets/                      Per-instrument asset definitions
|   |-- Asset.mqh                Base asset class (SEAsset)
|   |-- <AssetClass>/<Name>.mqh  One file per tradable instrument
|
|-- configs/
|   |-- Assets.mqh               Master asset registry: includes, instantiates, builds assets[]
|
|-- constants/                   Compile-time constants (times, codes, report paths, limits)
|
|-- entities/                    Domain entities
|   |-- EAccount.mqh             Account entity
|   |-- EOrder.mqh               Order entity (state machine record)
|   |-- ETradingStatus.mqh       Per-asset trading pause
|
|-- enums/                       Enumerations
|   |-- EDebugLevel.mqh          Log verbosity / persistence levels
|   |-- EOrderStatuses.mqh       Order state machine
|   |-- ETradeSeverity.mqh       Trade-retcode severity buckets
|
|-- helpers/                     Pure utility functions (H prefix)
|   |-- HGenerateUuid.mqh        Non-deterministic UUID (order IDs)
|   |-- HIsLiveTrading.mqh, HIsMarketClosed.mqh  Environment checks
|   |-- HGetReportsPath.mqh, HGetLogsPath.mqh  Report and log output paths
|   |-- HTradeRetcodeSeverity.mqh, HTradeRetcodeToLogCode.mqh  Retcode handling
|   |-- HStringToNumber.mqh       Generic utilities
|   |-- HResolveTransientDeferSeconds.mqh  Transient-error backoff
|
|-- indicators/                  Market-data functions (IN prefix, CopyXxx-based)
|   |-- INRollingReturn.mqh, INVolatility.mqh, INDrawdownFromPeak.mqh  Rolling stats
|   |-- INGetPriceValue.mqh       Price lookups
|   |-- INFairValueGap.mqh, INSwingPoints.mqh  Structural indicators
|
|-- interfaces/                  Abstract contracts
|   |-- IAsset.mqh                Asset interface
|   |-- IStrategy.mqh             Strategy interface (OnInit, OnStartHour, OnTick, ...)
|
|-- libraries/                   External/low-level MQL5 libraries
|   |-- Json/                     JSON serialization
|
|-- services/                    Framework services (SE = core, SR = persistence/report/reconciliation)
|   |-- SEDateTime/               Broker-aware datetime and broken-down time
|   |-- SEDb/                     JSON document store (pure MQL5, MT5 Common Files)
|   |-- SELogger/                 Structured logging
|   |-- SELotSize/                Position sizing (equity-at-risk)
|   |-- SEOrderBook/              Per-strategy order lifecycle
|   |-- SEStatistics/             Per-strategy performance/quality metrics
|   |-- SRAccountAuditor/         Account/order reconciliation
|   |-- SRPersistenceOfOrders/    Order JSON persistence (live only)
|   |-- SRPersistenceOfState/     Strategy key/value state persistence
|   |-- SRPersistenceOfStatistics/ Statistics persistence
|   |-- SRReportOfLogs/           Log export
|   |-- SRReportOfMarketSnapshots/ Market snapshot export
|   |-- SRReportOfOrderHistory/   Order history export
|   |-- SRReportOfStrategySnapshots/ Strategy snapshot export
|
|-- strategies/                  Strategy implementations
|   |-- Strategy.mqh              Base class (SEStrategy)
|   |-- <AssetClass>/<Instrument>/<Name>/<Name>.mqh  One folder per strategy
|   |-- Generic/                  Framework-provided strategies (Test)
|
|-- structs/                     Shared plain data structures
|   |-- SMarketStatus.mqh, STime.mqh, STradeResult.mqh, ...
|
|-- storage/                     Backtest INI files and results (git-ignored)
|
|-- scripts/                     Build, sync, and utility scripts
|
|-- logs/                        Runtime log output
|
|-- docs/                        Documentation (this directory)
```

Asset and strategy folders follow a fixed path convention so the registry, magic-number hashing, and log namespacing all line up:

```
assets/<AssetClass>/<Instrument>.mqh
strategies/<AssetClass>/<Instrument>/<Name>/<Name>.mqh
```

See [Reference > Naming Conventions](../reference/naming-conventions.md) for prefix rules and identifier policy.
