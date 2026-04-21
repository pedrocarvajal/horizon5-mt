# Architecture Overview

High-level view of how Horizon5 is wired. For the rationale behind these choices, see [Explanation > Design Decisions](../explanation/design-decisions.md). For the service model in depth, see [Explanation > Service Architecture](../explanation/service-architecture.md).

## Process topology

```
+--------------------------------------------------------------+
|                      Horizon.mq5  (EA)                       |
|                                                              |
|   Event loop  ─────────► Assets ─► Strategies ─► OrderBooks  |
|                                                              |
|   Inputs    → risk model, reporting, integrations            |
|   Services  → SEDateTime, SELogger, SELotSize, SEStatistics, |
|               SEOrderBook, SEMessageBus, SEGateway, ...      |
|   Entities  → EAccount, EAsset, EOrder                       |
+---------------------------+----------------------------------+
                            |
                    MessageBus DLL (shared memory)
                            |
   +------------------------+----------------------------+
   |                        |                            |
+--v--------------+  +------v----------+   +-------------v------+
| HorizonPersist. |  | HorizonGateway  |   | HorizonMonitor     |
| (.mq5 service)  |  | (.mq5 service)  |   | (.mq5 service)     |
+-----------------+  +-----------------+   +--------------------+
```

The EA is the only process that holds trading state. Services are stateless relays: they poll their assigned channels, perform I/O, and ACK messages.

## Hierarchy inside the EA

```
EA
├── EAccount (static account entity)
└── SEAsset[]                 (1 per tradable instrument)
     └── SEStrategy[]          (1..N per asset)
          └── SEOrderBook       (1 per strategy)
               └── EOrder[]      (lifecycle records)
```

Events flow top-down through `OnTimer`/primed-bar dispatch; trade transactions flow bottom-up through magic-number routing.

## Message bus channels

| Channel           | Direction        | Purpose                                                  |
| ----------------- | ---------------- | -------------------------------------------------------- |
| `connector`       | EA → Monitor     | Outbound HTTP POST bodies                                |
| `persistence`     | EA → Persistence | File-write requests (JSON order state, statistics)       |
| `events_inbound`  | Gateway → EA     | Remote trading events (post/delete/put/get order)        |
| `events_outbound` | EA → Gateway     | ACK responses to inbound events                          |
| `events_service`  | Gateway → EA     | Service-level events (account info, assets, klines, ...) |

Each message carries a `messageType` and a JSON payload; every message has a monotonic sequence number that enables ACK-based flow control and deduplication.

## Extension surface

- **Add a strategy** — create a subclass of `SEStrategy` under `strategies/.../` and register it in an asset file.
- **Add an asset** — create a subclass of `SEAsset` under `assets/.../` and register it in `configs/Assets.mqh`.
- **Add a helper / indicator** — drop a file in `helpers/` or `indicators/` following the `H` / `IN` naming convention.
- **Add a service** — new `SE` / `SR` folder under `services/` with its own public surface.
- **Add a standalone service script** — new `.mq5` file at the root using `SEMessageBus` to register as a named service and poll its channel.
