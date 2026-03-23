# Project Structure

```
Horizon5/
|-- Horizon.mq5                  Main Expert Advisor entry point
|-- HorizonPersistence.mq5       Service: async file I/O via MessageBus
|-- HorizonGateway.mq5           Service: remote order management via Horizon API
|-- HorizonMonitor.mq5           Service: monitoring data relay to Horizon API
|
|-- adapters/
|   |-- ATrade.mqh               Trade execution adapter wrapping MT5's CTrade
|
|-- assets/                      Asset definitions, one file per instrument
|   |-- Asset.mqh                Base asset class (SEAsset)
|   |-- Commodities/
|   |   |-- Gold.mqh             Gold (XAUUSD) -- registers Gold strategies
|   |-- Crypto/
|   |   |-- Bitcoin.mqh          Bitcoin -- registers Bitcoin strategies
|   |-- Indices/
|       |-- SP500.mqh            S&P 500 -- registers SP500 strategies
|       |-- Nikkei225.mqh        Nikkei 225 -- registers Nikkei strategies
|
|-- configs/
|   |-- Assets.mqh               Master asset registry (includes all asset files, builds the assets[] array)
|
|-- constants/
|   |-- time.mqh                 Time-related constants
|
|-- entities/
|   |-- EAccount.mqh             Account entity
|   |-- EAsset.mqh               Asset entity
|   |-- EOrder.mqh               Order entity
|
|-- enums/
|   |-- EDebugLevel.mqh          Debug log levels
|   |-- EHeartbeatEvent.mqh      Heartbeat event types
|   |-- ELogSystem.mqh           Log system identifiers
|   |-- EOrderStatuses.mqh       Order status enum
|   |-- ETradingPauseReason.mqh  Trading pause reasons
|
|-- helpers/                     Utility functions (pure computation, no market data)
|   |-- HClampNumeric.mqh        Clamp a value within bounds
|   |-- HGenerateUuid.mqh        UUID generation
|   |-- HGenerateDeterministicUuid.mqh  Deterministic UUID from seed
|   |-- HGetAccountUuid.mqh      Account UUID helper
|   |-- HGetAssetRate.mqh        Asset conversion rate
|   |-- HGetAssetUuid.mqh        Asset UUID helper
|   |-- HGetCloseReason.mqh      Map deal reason to string
|   |-- HGetLogsPath.mqh         Resolve logs directory path
|   |-- HGetOrderSide.mqh        Map order type to side string
|   |-- HGetOrderStatus.mqh      Map order status to string
|   |-- HGetPipSize.mqh          Pip size for a symbol
|   |-- HGetPipValue.mqh         Pip value for a symbol
|   |-- HGetReportsPath.mqh      Resolve reports directory path
|   |-- HGetStrategyUuid.mqh     Strategy UUID helper
|   |-- HInitializeMessageBus.mqh  MessageBus bootstrap
|   |-- HIsLiveTrading.mqh       Detect live vs. tester mode
|   |-- HIsMarketClosed.mqh      Market session check
|   |-- HMapTimeframe.mqh        Map timeframe to string
|   |-- HStringToNumber.mqh      String-to-numeric conversion
|   |-- trading/                   Trading helpers (indicator wrappers, signal checks)
|       |-- HCheckStopDistance.mqh   Validate stop distance from market
|       |-- HCrossedAbove.mqh       Cross-above detection
|       |-- HDailyPerformance.mqh   Daily performance calculation
|       |-- HDrawdownFromPeak.mqh   Drawdown from peak helper
|       |-- HFixMarketPrice.mqh     Normalize price to tick size
|       |-- HGetIndicatorValue.mqh  Read indicator buffer values
|       |-- HIsHigherFor.mqh        Higher-for-N-bars check
|       |-- HIsRising.mqh           Rising/falling detection
|       |-- HNormalizeLotSize.mqh   Normalize lot size to broker constraints
|       |-- HRollingReturn.mqh      Rolling return calculation
|       |-- HVolatility.mqh         Volatility calculation
|
|-- indicators/                  Market data functions (use CopyXxx), prefixed IN
|   |-- INDailyPerformance.mqh   Daily performance indicator
|   |-- INDrawdownFromPeak.mqh   Drawdown from peak indicator
|   |-- INGetPriceValue.mqh      Price value extractor
|   |-- INHighest.mqh            Highest value indicator
|   |-- INRollingReturn.mqh      Rolling return indicator
|   |-- INVolatility.mqh         Volatility indicator
|
|-- integrations/                External API client libraries
|   |-- HorizonGateway/          Gateway API client (authentication, events, orders)
|   |   |-- resources/           API resource handlers
|   |   |-- structs/             Gateway-specific data structures
|   |-- HorizonMonitor/          Monitor API client (snapshots, orders, logs)
|   |   |-- resources/           API resource handlers
|   |   |-- structs/             Monitor-specific data structures
|   |-- Shared/                  Shared integration utilities (base HTTP client, auth)
|
|-- interfaces/
|   |-- IAsset.mqh               Asset interface
|   |-- IEventHandler.mqh        Event handler interface
|   |-- IRemoteLogger.mqh        Remote logging interface
|   |-- IStrategy.mqh            Strategy interface (OnInit, OnStartHour, OnTick, etc.)
|
|-- libraries/
|   |-- HorizonMessageBus/       Inter-process communication DLL (shared memory message bus)
|   |   |-- build/               Compiled DLL binaries
|   |   |-- constants/           Channel and service constants
|   |   |-- entities/            Message entities
|   |   |-- helpers/             Bus helper functions
|   |   |-- services/            Bus service implementations
|   |-- Json/                    JSON parsing library
|
|-- services/                    18 services, organized by prefix
|   |-- SE* (core services):
|   |   |-- SEDateTime/          Date/time utilities with broker-aware timestamps
|   |   |-- SEDb/                Database abstraction layer
|   |   |-- SELogger/            Logging service with global and per-strategy scopes
|   |   |-- SELotSize/           Position sizing engine (equity-at-risk based)
|   |   |-- SEMessageBus/        MessageBus client wrapper (send, poll, ack)
|   |   |-- SEOrderBook/         Order lifecycle management (place, close, cancel, expire)
|   |   |-- SERequest/           HTTP request service
|   |   |-- SEStatistics/        Strategy performance statistics
|   |-- SR* (persistence, reports, and integrations):
|       |-- SRImplementationOfHorizonGateway/   Gateway integration for the EA
|       |-- SRImplementationOfHorizonMonitor/   Monitor integration for the EA
|       |-- SRPersistenceOfOrders/              Order state persistence via MessageBus
|       |-- SRPersistenceOfState/               Strategy state persistence (key-value store)
|       |-- SRPersistenceOfStatistics/          Statistics persistence via MessageBus
|       |-- SRRemoteOrderManager/               Remote order execution from Gateway events
|       |-- SRReportOfLogs/                     Log export to CSV
|       |-- SRReportOfMarketSnapshots/          Market snapshot export to CSV
|       |-- SRReportOfOrderHistory/             Order history export to CSV
|       |-- SRReportOfStrategySnapshots/        Strategy snapshot export to CSV
|
|-- strategies/                  Trading strategies, organized by asset class
|   |-- Strategy.mqh             Base class (SEStrategy) -- all strategies extend this
|   |-- Commodities/
|   |   |-- Gold/                Australian city names (Ballarat, Bendigo, Cairns, Darwin,
|   |                            Geelong, Hobart, Mackay, Tamworth, Toowoomba, Wollongong)
|   |-- Indices/
|   |   |-- Nikkei225/           Japanese city names (Fukuoka, Kobe, Kyoto, Nagoya, Nara,
|   |   |                        Niigata, Nikko, Osaka, Sapporo, Yokohama)
|   |   |-- SP500/               American city names (Austin, Charlotte, Denver, Memphis,
|   |                            Nashville, Phoenix, Portland, Raleigh, Tampa, Tucson)
|   |-- Generic/
|       |-- Gateway/             Remote order execution strategy (used by HorizonGateway)
|       |-- Test/                Test/debug strategy
|
|-- structs/                     Shared data structures
|   |-- SMarketStatus.mqh        Market status snapshot
|   |-- SSMarketSnapshot.mqh     Market snapshot for reporting
|   |-- SSOrderHistory.mqh       Order history record
|   |-- SSQualityResult.mqh      Strategy quality result
|   |-- SSStatisticsSnapshot.mqh Statistics snapshot for reporting
|   |-- SStatisticsState.mqh     Statistics state
|   |-- STime.mqh                Time struct (hour + minute)
|   |-- STradingStatus.mqh       Trading status flags
|
|-- storage/
|   |-- sets/                    MT5 parameter set files (.set) for backtesting
|
|-- scripts/                     Build and utility scripts
|   |-- helpers/                 Shell script helpers
|   |-- make/                    Compilation scripts
|   |-- python/                  Python utilities
|
|-- logs/                        Runtime log output directory
|
|-- docs/                        Documentation
    |-- getting-started/         Installation, structure, first strategy
    |-- how-to/                  Task-oriented guides
    |-- reference/               API and class reference
    |-- explanation/             Architecture and design decisions
    |-- architecture/            System diagrams
    |-- strategies/              Strategy documentation and source specs
    |-- tutorials/               Step-by-step tutorials
    |-- examples/                Code examples
    |-- requests/                Feature and change requests
```
