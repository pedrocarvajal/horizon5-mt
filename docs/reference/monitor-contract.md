# Monitor Contract

Canonical values that Horizon EA emits to `horizon5-monitor` via `integrations/HorizonMonitor/`. This file is the **source of truth** for the monitor-side enums, validators, and UI renderers.

Any change to the helpers listed below must be mirrored in the monitor backend in the same PR.

## Order status

Source helper: `helpers/HGetOrderStatus.mqh` → maps `ENUM_ORDER_STATUSES` to wire values.

| Wire value  | When emitted                                                 | Internal state (EA)      | Monitor bucket            |
| ----------- | ------------------------------------------------------------ | ------------------------ | ------------------------- |
| `pending`   | Limit/stop order placed, waiting for fill                    | `ORDER_STATUS_PENDING`   | active                    |
| `open`      | Broker confirmed fill, position live                         | `ORDER_STATUS_OPEN`      | active                    |
| `closing`   | Close signal issued, awaiting broker confirmation            | `ORDER_STATUS_CLOSING`   | active                    |
| `closed`    | Broker confirmed exit, final PnL recorded                    | `ORDER_STATUS_CLOSED`    | terminal, realized PnL    |
| `cancelled` | Limit/pending order cancelled before fill, or close rejected | `ORDER_STATUS_CANCELLED` | terminal, no realized PnL |

State machine diagram: see `docs/reference/order-states.md`.

## Order side

Source helper: `helpers/HGetOrderSide.mqh` → maps `ORDER_TYPE_*` to wire values.

| Wire value | When emitted                                                                                     |
| ---------- | ------------------------------------------------------------------------------------------------ |
| `buy`      | `ORDER_TYPE_BUY`, `ORDER_TYPE_BUY_LIMIT`, `ORDER_TYPE_BUY_STOP`, `ORDER_TYPE_BUY_STOP_LIMIT`     |
| `sell`     | `ORDER_TYPE_SELL`, `ORDER_TYPE_SELL_LIMIT`, `ORDER_TYPE_SELL_STOP`, `ORDER_TYPE_SELL_STOP_LIMIT` |

## Close reason

Source helper: `helpers/HGetCloseReason.mqh` → maps `ENUM_DEAL_REASON` to wire values. Only sent when `status=closed`.

| Wire value | When emitted                                        |
| ---------- | --------------------------------------------------- |
| `tp`       | `DEAL_REASON_TP` — take profit hit                  |
| `sl`       | `DEAL_REASON_SL` — stop loss hit                    |
| `expert`   | `DEAL_REASON_EXPERT` — EA-driven close              |
| `client`   | `DEAL_REASON_CLIENT` — manual close from terminal   |
| `mobile`   | `DEAL_REASON_MOBILE` — manual close from mobile app |
| `web`      | `DEAL_REASON_WEB` — manual close from web terminal  |

## Heartbeat event

Source: `constants/COHeartbeat.mqh` and `integrations/HorizonMonitor/resources/HeartbeatResource.mqh`.

| Wire value | Meaning                              |
| ---------- | ------------------------------------ |
| `running`  | EA / service is alive and processing |

## Metadata format

Source: `integrations/HorizonMonitor/resources/{AccountMetadata,AssetMetadata}Resource.mqh` + `entities/E{Account,Asset}.mqh`.

Each metadata entry has the shape `{ key, label, value, format }` where `format ∈ { string, integer, decimal, boolean, json }`. The monitor side defines the enum in `app/Enums/MetadataFormat.php`.

## Evolution rules

1. **The EA helper is the source of truth.** If you need a new order status (e.g. `partially_closed`), add it to `helpers/HGetOrderStatus.mqh` first, then update this file and the monitor enum in the same PR.
2. **Never remove a wire value.** If a state becomes obsolete, stop emitting it from the EA but keep the monitor enum case for historical rows.
