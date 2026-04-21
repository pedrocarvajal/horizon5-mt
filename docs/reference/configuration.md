# Configuration

All input parameters exposed by `Horizon.mq5`, grouped exactly as they appear in MT5's inputs dialog.

## General Settings

| Parameter          | Type                      | Default             | Description                                                  |
| ------------------ | ------------------------- | ------------------- | ------------------------------------------------------------ |
| `TickIntervalTime` | `int`                     | `60`                | Tick interval in seconds. Controls how often `OnTick` fires. |
| `FillingMode`      | `ENUM_ORDER_TYPE_FILLING` | `ORDER_FILLING_IOC` | Broker fill policy for outbound orders.                      |
| `DebugLevel`       | `ENUM_DEBUG_LEVEL`        | `DEBUG_LEVEL_ALL`   | Log verbosity and optional file persistence.                 |

### Debug levels

| Value                        | Behavior                               |
| ---------------------------- | -------------------------------------- |
| `DEBUG_LEVEL_NONE`           | No logs                                |
| `DEBUG_LEVEL_ERRORS`         | Errors and warnings only               |
| `DEBUG_LEVEL_ERRORS_PERSIST` | Errors and warnings, persisted to file |
| `DEBUG_LEVEL_ALL`            | All logs                               |
| `DEBUG_LEVEL_ALL_PERSIST`    | All logs, persisted to file            |

## Reporting > Strategy Reports

Per-strategy exports, primarily intended for tester runs.

| Parameter                     | Type   | Default | Description                       |
| ----------------------------- | ------ | ------- | --------------------------------- |
| `EnableOrderHistoryReport`    | `bool` | `false` | Export per-strategy order history |
| `EnableSnapshotHistoryReport` | `bool` | `false` | Export per-strategy snapshots     |
| `EnableMarketHistoryReport`   | `bool` | `false` | Export per-asset market snapshots |

## Reporting > Monitor Seed

Dataset seeding for the Monitor backend. Produces structured collections during backtest runs so external systems can bootstrap from tester output.

| Parameter              | Type   | Default | Description                             |
| ---------------------- | ------ | ------- | --------------------------------------- |
| `EnableSeedAccounts`   | `bool` | `false` | Export accounts collection              |
| `EnableSeedAssets`     | `bool` | `false` | Export assets collection                |
| `EnableSeedStrategies` | `bool` | `false` | Export strategies collection            |
| `EnableSeedMetadata`   | `bool` | `false` | Export metadata collection              |
| `EnableSeedOrders`     | `bool` | `false` | Export orders collection                |
| `EnableSeedSnapshots`  | `bool` | `false` | Export account/asset/strategy snapshots |

## Reporting > Logs

| Parameter         | Type   | Default | Description                          |
| ----------------- | ------ | ------- | ------------------------------------ |
| `EnableLogExport` | `bool` | `false` | Export portfolio logs on EA shutdown |

## Risk management

| Parameter                | Type     | Default | Description                                                           |
| ------------------------ | -------- | ------- | --------------------------------------------------------------------- |
| `EquityAtRiskCompounded` | `bool`   | `false` | Use current NAV instead of the initial allocation when computing risk |
| `EquityAtRisk`           | `double` | `1`     | Maximum equity at risk per trade, as a percentage                     |

## Horizon Monitor

Optional outbound telemetry integration. Active only in live trading.

| Parameter                | Type     | Default | Description                              |
| ------------------------ | -------- | ------- | ---------------------------------------- |
| `EnableHorizonMonitor`   | `bool`   | `false` | Toggle the Monitor integration on or off |
| `HorizonMonitorUrl`      | `string` | `""`    | Base URL of the Monitor backend          |
| `HorizonMonitorEmail`    | `string` | `""`    | Authentication email                     |
| `HorizonMonitorPassword` | `string` | `""`    | Authentication password                  |

## Horizon Gateway

Optional inbound orchestration integration. Active only in live trading.

| Parameter                | Type     | Default | Description                              |
| ------------------------ | -------- | ------- | ---------------------------------------- |
| `EnableHorizonGateway`   | `bool`   | `false` | Toggle the Gateway integration on or off |
| `HorizonGatewayUrl`      | `string` | `""`    | Base URL of the Gateway backend          |
| `HorizonGatewayEmail`    | `string` | `""`    | Authentication email                     |
| `HorizonGatewayPassword` | `string` | `""`    | Authentication password                  |

## Asset-level strategy toggles

Each asset file defines `input bool` toggles for its strategies. The naming pattern is:

```
<Instrument><Strategy>Enabled
```

All default to `false`. The specific set of toggles depends on which assets and strategies you have registered — see the corresponding asset file under `assets/<AssetClass>/<Instrument>.mqh`.

## Service-level inputs

The standalone service scripts expose their own inputs when started as MT5 services:

- `HorizonPersistence.mq5` — `DebugLevel`, `PollIntervalMs`.
- `HorizonMonitor.mq5` — `DebugLevel`, `HorizonMonitorUrl`, `HorizonMonitorEmail`, `HorizonMonitorPassword`.
- `HorizonGateway.mq5` — `DebugLevel`, `HorizonGatewayUrl`, `HorizonGatewayEmail`, `HorizonGatewayPassword`.

The Monitor/Gateway service inputs must match the values configured in the EA.
