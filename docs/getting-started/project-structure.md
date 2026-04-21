# Project Structure

```
Horizon5/
|-- Horizon.mq5                  Main Expert Advisor (portfolio orchestrator)
|-- HorizonPersistence.mq5       Service: async file I/O via MessageBus
|-- HorizonGateway.mq5           Service: remote order/event ingestion
|-- HorizonMonitor.mq5           Service: outbound telemetry relay
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
|-- constants/                   Compile-time constants (times, codes, topics, limits)
|
|-- entities/                    Domain entities
|   |-- EAccount.mqh             Account entity
|   |-- EAsset.mqh               Asset entity
|   |-- EOrder.mqh               Order entity (state machine record)
|
|-- enums/                       Enumerations
|   |-- EDebugLevel.mqh          Log verbosity / persistence levels
|   |-- EOrderStatuses.mqh       Order state machine
|   |-- ESnapshotEvent.mqh       Snapshot trigger events
|   |-- ESystemName.mqh          Logical system identifiers
|   |-- ETradeSeverity.mqh       Trade-retcode severity buckets
|   |-- ETradingPauseReason.mqh  Typed reasons for trading pause
|
|-- helpers/                     Pure utility functions (H prefix)
|   |-- HGenerateUuid.mqh        Non-deterministic UUID
|   |-- HGenerateDeterministicUuid.mqh  Seeded UUID v5-style
|   |-- HGet*Uuid.mqh            Canonical UUID helpers (account, asset, strategy, order)
|   |-- HGetPipSize.mqh, HGetPipValue.mqh  Symbol arithmetic
|   |-- HGetOrderSide.mqh, HGetOrderStatus.mqh, HGetCloseReason.mqh  Wire-format mappers
|   |-- HIsLiveTrading.mqh, HIsLiveEnvironment.mqh, HIsMarketClosed.mqh  Environment checks
|   |-- HInitializeMessageBus.mqh  Message bus bootstrap
|   |-- HTradeRetcodeSeverity.mqh, HTradeRetcodeToLogCode.mqh  Retcode handling
|   |-- HDraw*.mqh                Chart annotation helpers
|   |-- HMapTimeframe.mqh, HClampNumeric.mqh, HStringToNumber.mqh  Generic utilities
|   |-- HResolveTransientDeferSeconds.mqh  Transient-error backoff
|
|-- indicators/                  Market-data functions (IN prefix, CopyXxx-based)
|   |-- INRollingReturn.mqh, INVolatility.mqh, INDrawdownFromPeak.mqh  Rolling stats
|   |-- INHighest.mqh, INGetPriceValue.mqh  Price lookups
|   |-- INDailyPerformance.mqh    Day-level performance
|   |-- INFairValueGap.mqh, INSwingPoints.mqh  Structural indicators
|
|-- integrations/                External API clients used by the services
|   |-- HorizonGateway/           Gateway API client (auth, events, orders, service queries)
|   |-- HorizonMonitor/           Monitor API client (snapshots, orders, heartbeats, logs)
|   |-- Shared/                   Shared HTTP and authentication primitives
|
|-- interfaces/                  Abstract contracts
|   |-- IAsset.mqh                Asset interface
|   |-- IStrategy.mqh             Strategy interface (OnInit, OnStartHour, OnTick, ...)
|   |-- IEventHandler.mqh         Generic event handler contract
|   |-- IRemoteLogger.mqh         Remote log sink contract
|
|-- libraries/                   External/low-level MQL5 libraries
|   |-- HorizonMessageBus/        Shared-memory IPC DLL (the message bus)
|   |-- Json/                     JSON serialization
|
|-- services/                    Framework services (SE = core, SR = report/remote)
|   |-- SEDateTime/               Broker-aware datetime and broken-down time
|   |-- SEDb/                     File-backed key/value store
|   |-- SEGateway/                Per-asset inbound/outbound gateway routing
|   |-- SELogger/                 Structured logging with optional remote sink
|   |-- SELotSize/                Position sizing (equity-at-risk)
|   |-- SEMessageBus/             Message bus client (send/poll/ack/health)
|   |-- SEOrderBook/              Per-strategy order lifecycle
|   |-- SERequest/                HTTP request wrapper
|   |-- SEStatistics/             Per-strategy performance/quality metrics
|   |-- SRAccountAuditor/         Account/order reconciliation
|   |-- SRImplementationOfHorizonGateway/  EA-side Gateway integration
|   |-- SRImplementationOfHorizonMonitor/  EA-side Monitor integration
|   |-- SRPersistenceOfOrders/    Order JSON persistence (via bus in live)
|   |-- SRPersistenceOfState/     Strategy key/value state persistence
|   |-- SRPersistenceOfStatistics/ Statistics persistence
|   |-- SRReportOfLogs/           Log export
|   |-- SRReportOfMarketSnapshots/ Market snapshot export
|   |-- SRReportOfMonitorSeed/    Monitor dataset seeding for backtests
|   |-- SRReportOfOrderHistory/   Order history export
|   |-- SRReportOfStrategySnapshots/ Strategy snapshot export
|
|-- strategies/                  Strategy implementations
|   |-- Strategy.mqh              Base class (SEStrategy)
|   |-- <AssetClass>/<Instrument>/<Name>/<Name>.mqh  One folder per strategy
|   |-- Generic/                  Framework-provided strategies (Gateway, Test)
|
|-- structs/                     Shared plain data structures
|   |-- SMarketStatus.mqh, STime.mqh, STradingStatus.mqh, STradeResult.mqh, ...
|
|-- storage/                     Runtime-writable storage (MT5 parameter .set files, etc.)
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
