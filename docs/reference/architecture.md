# Architecture Overview

High-level view of how Horizon5 is wired. For the rationale behind these choices, see [Explanation > Design Decisions](../explanation/design-decisions.md).

## Process topology

```
+--------------------------------------------------------------+
|                      Horizon.mq5  (EA)                       |
|                                                              |
|   Event loop  ─────────► Assets ─► Strategies ─► OrderBooks  |
|                                                              |
|   Inputs    → risk model, reporting                          |
|   Services  → SEDateTime, SELogger, SELotSize, SEStatistics, |
|               SEOrderBook, SEDb, ...                         |
|   Entities  → EAccount, EOrder, ETradingStatus               |
+--------------------------------------------------------------+
```

The EA is a single self-contained program and the only process that holds trading state. It loads no DLLs, needs no companion MT5 services, and makes no WebRequest calls; all persistence and reporting is plain JSON written through `SEDb`.

## Hierarchy inside the EA

```
EA
├── EAccount (static account entity)
└── SEAsset[]                 (1 per tradable instrument)
     ├── ETradingStatus        (the asset's trading pause)
     └── SEStrategy[]          (1..N per asset)
          └── SEOrderBook       (1 per strategy)
               └── EOrder[]      (lifecycle records)
```

Events flow top-down through `OnTimer`/primed-bar dispatch; trade transactions flow bottom-up through magic-number routing.

## Files on disk

All files live under MT5's Common Files folder, namespaced by account login.

| Path                                                  | Written by                    | When                                           |
| ----------------------------------------------------- | ----------------------------- | ---------------------------------------------- |
| `<login>\Live\<symbol>\<prefix>\orders.json`          | `SRPersistenceOfOrders`       | Live trading, on every order transition        |
| `<login>\Live\<symbol>\<prefix>\statistics.json`      | `SRPersistenceOfStatistics`   | Live trading                                   |
| `<login>\Live\<symbol>\<prefix>\state.json`           | `SRPersistenceOfState`        | Live trading                                   |
| `<login>\Reports\<symbol>_<prefix>_Orders.json`       | `SRReportOfOrderHistory`      | `OnTester()`, if `EnableOrderHistoryReport`    |
| `<login>\Reports\<symbol>_<prefix>_Snapshots.json`    | `SRReportOfStrategySnapshots` | `OnTester()`, if `EnableSnapshotHistoryReport` |
| `<login>\Reports\<symbol>_MARKET_Snapshots.json`      | `SRReportOfMarketSnapshots`   | `OnTester()`, if `EnableMarketHistoryReport`   |
| `<login>\Logs\Portfolio\<timestamp>_<seed>\Logs.json` | `SRReportOfLogs`              | EA shutdown, if `EnableLogExport`              |

## Extension surface

- **Add a strategy** — create a subclass of `SEStrategy` under `strategies/.../` and register it in an asset file.
- **Add an asset** — create a subclass of `SEAsset` under `assets/.../` and register it in `configs/Assets.mqh`.
- **Add a helper / indicator** — drop a file in `helpers/` or `indicators/` following the `H` / `IN` naming convention.
- **Add a service** — new `SE` / `SR` folder under `services/` with its own public surface.
