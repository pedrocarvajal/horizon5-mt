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

## Reporting > Logs

| Parameter         | Type   | Default | Description                          |
| ----------------- | ------ | ------- | ------------------------------------ |
| `EnableLogExport` | `bool` | `false` | Export portfolio logs on EA shutdown |

## Risk management

| Parameter                | Type     | Default | Description                                                           |
| ------------------------ | -------- | ------- | --------------------------------------------------------------------- |
| `EquityAtRiskCompounded` | `bool`   | `false` | Use current NAV instead of the initial allocation when computing risk |
| `EquityAtRisk`           | `double` | `1`     | Maximum equity at risk per trade, as a percentage                     |

## Asset-level strategy toggles

Each asset file defines `input bool` toggles for its strategies. The naming pattern is:

```
<Instrument><Strategy>Enabled
```

All default to `false`. The specific set of toggles depends on which assets and strategies you have registered — see the corresponding asset file under `assets/<AssetClass>/<Instrument>.mqh`.
