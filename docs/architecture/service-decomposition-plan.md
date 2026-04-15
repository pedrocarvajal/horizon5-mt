# Service Decomposition Plan

## Problem Statement

MetaTrader 5 runs the Expert Advisor (EA) on a **single thread**. Every `WebRequest` (up to 5s timeout) and every `FileWrite` (SEDb flush) blocks this thread. The EA currently performs:

- **11 types of HTTP calls** directly from the trading thread (orders, snapshots, logs, heartbeats, account sync)
- **3 types of file persistence** with auto-flush on every change (orders, state, statistics)
- **Remote logging on every log call** — each `logger.Info/Debug/Error/Warning` triggers a `WebRequest`

**Impact:** During an hourly sync with 20 strategies and 10 open orders, the EA thread can block for **30-60+ seconds** (each HTTP call = 1-5s). During trading, every order open/close blocks for ~5s on `UpsertOrder`. Every log call blocks for ~5s on `StoreLog`.

**Goal:** Move ALL blocking I/O out of the EA thread. The EA should only execute trading logic and send non-blocking messages (<1ms) to dedicated services.

---

## Current Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Horizon.mq5 (EA)                           │
│                      Single Thread                              │
│                                                                 │
│  OnTimer (every 1s):                                            │
│  ├── Strategy evaluation (fast)                                 │
│  ├── Order management (fast)                                    │
│  ├── [BLOCKS] horizonAPI.UpsertAccount()          ~5s / hourly  │
│  ├── [BLOCKS] horizonAPI.UpsertStrategy() x N     ~5s each / h  │
│  ├── [BLOCKS] horizonAPI.UpsertOrder() x N        ~5s each / h  │
│  ├── [BLOCKS] horizonAPI.StoreStrategySnapshot()  ~5s each / h  │
│  ├── [BLOCKS] horizonAPI.StoreAccountSnapshot()   ~5s / hourly  │
│  └── [BLOCKS] horizonAPI.StoreHeartbeat() x N     ~5s each / h  │
│                                                                 │
│  OnTradeTransaction:                                            │
│  ├── [BLOCKS] horizonAPI.UpsertOrder()            ~5s / trade   │
│  ├── [BLOCKS] SEDbCollection.Flush() (orders)     ~500ms / trade│
│  ├── [BLOCKS] SEDbCollection.Flush() (statistics) ~500ms / trade│
│  └── [BLOCKS] SEDbCollection.Flush() (state)      ~500ms / chg  │
│                                                                 │
│  Every log call:                                                │
│  └── [BLOCKS] horizonAPI.StoreLog()               ~5s / log    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   HorizonAPI.mq5 (Service)                      │
│                   Own Thread (already offloaded)                 │
│                                                                 │
│  Loop (every 3s):                                               │
│  ├── ConsumeEvents("get.account.info")                          │
│  ├── ConsumeEvents("get.ticker")                                │
│  └── ConsumeEvents("get.klines")                                │
│  (Processes inbound events from remote API)                     │
└─────────────────────────────────────────────────────────────────┘

Communication: NONE between EA and Service (both talk to remote API independently)
```

### Blocking Operations Inventory

| #   | Operation                                | Source File                          | Trigger                 | Block Type | Duration | Frequency           |
| --- | ---------------------------------------- | ------------------------------------ | ----------------------- | ---------- | -------- | ------------------- |
| 1   | `horizonAPI.StoreLog()`                  | `SELogger.mqh:99`                    | Every log call          | WebRequest | ~5s      | Hundreds/day        |
| 2   | `horizonAPI.UpsertOrder()`               | `Strategy.mqh:251,307,316`           | Order open/close/cancel | WebRequest | ~5s      | Per trade           |
| 3   | `horizonAPI.UpsertOrder()`               | `Strategy.mqh:350`                   | Hourly sync             | WebRequest | ~5s      | Per open order/hour |
| 4   | `horizonAPI.UpsertAccount()`             | `Horizon.mq5:254`                    | Hourly                  | WebRequest | ~5s      | Hourly              |
| 5   | `horizonAPI.UpsertStrategy()`            | `Asset.mqh:493`                      | Hourly                  | WebRequest | ~5s      | Per strategy/hour   |
| 6   | `horizonAPI.StoreStrategySnapshot()`     | `Strategy.mqh:373`                   | Hourly                  | WebRequest | ~5s      | Per strategy/hour   |
| 7   | `horizonAPI.StoreAccountSnapshot()`      | `Horizon.mq5:273`                    | Hourly                  | WebRequest | ~5s      | Hourly              |
| 8   | `horizonAPI.StoreHeartbeat()`            | `Asset.mqh:512`                      | Hourly                  | WebRequest | ~5s      | Per strategy/hour   |
| 9   | `SEDbCollection.Flush()` via `SaveOrder` | `SEOrderBook.mqh:424,492,540`        | Order state change      | FileWrite  | ~500ms   | Per order change    |
| 10  | `SEDbCollection.Flush()` via `SetXxx`    | `SRPersistenceOfState.mqh:78,97,...` | Strategy state change   | FileWrite  | ~500ms   | Variable            |
| 11  | `SEDbCollection.Flush()` via `Save`      | `SRPersistenceOfStatistics.mqh`      | Order close + daily     | FileWrite  | ~500ms   | Per close + daily   |
| 12  | `SRReportOfLogs.Export()`                | `Horizon.mq5:178`                    | EA shutdown             | FileWrite  | ~1s      | Once                |

---

## Target Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Horizon.mq5 (EA)                       │
│                    Single Thread                          │
│                                                          │
│  OnTimer (every 1s):                                     │
│  ├── Strategy evaluation (fast)                          │
│  ├── Order management (fast)                             │
│  └── MessageBus.Send() for API sync data    <1ms         │
│                                                          │
│  OnTradeTransaction:                                     │
│  ├── MessageBus.Send() for order upsert     <1ms         │
│  └── MessageBus.Send() for persistence      <1ms         │
│                                                          │
│  Every log call:                                         │
│  └── MessageBus.Send() for remote log       <1ms         │
│                                                          │
│  NO WebRequest. NO FileWrite. Trading only.              │
└──────┬────────────────┬────────────────┬─────────────────┘
       │                │                │
       │ "connector"    │ "persistence"  │ "events"
       │ channel        │ channel        │ channel
       │                │                │
┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────────────┐
│ Service 1   │  │ Service 2   │  │ Service 3           │
│             │  │             │  │                     │
│ HorizonAPI  │  │ Horizon     │  │ HorizonAPI          │
│ Connector   │  │ Persistence │  │ Events              │
│ (NEW)       │  │ (NEW)       │  │ (REPLACES current)  │
│             │  │             │  │                     │
│ Outbound    │  │ All file    │  │ Bidirectional       │
│ HTTP calls  │  │ I/O         │  │ event processing    │
└─────────────┘  └─────────────┘  └─────────────────────┘
```

### Service 1: HorizonAPI-Connector

**File:** `HorizonAPIConnector.mq5`

**Responsibility:** ALL outbound HTTP communication with the HorizonAPI remote server.

**Consumes messages from EA on channel `connector`:**

| Message Type              | Payload                                           | Original Blocking Call               |
| ------------------------- | ------------------------------------------------- | ------------------------------------ |
| `upsert_account`          | Account data                                      | `horizonAPI.UpsertAccount()`         |
| `upsert_strategy`         | Strategy name, symbol, prefix, magic, balance     | `horizonAPI.UpsertStrategy()`        |
| `upsert_order`            | Full EOrder serialization                         | `horizonAPI.UpsertOrder()`           |
| `store_log`               | level, message, magicNumber                       | `horizonAPI.StoreLog()`              |
| `store_heartbeat`         | magicNumber, event, systemName                    | `horizonAPI.StoreHeartbeat()`        |
| `store_account_snapshot`  | drawdown, pnl, floating, orders, lots             | `horizonAPI.StoreAccountSnapshot()`  |
| `store_strategy_snapshot` | magic, nav, drawdown, pnl, floating, orders, lots | `horizonAPI.StoreStrategySnapshot()` |

**Internal optimizations:**

- **Log batching:** Accumulate log messages and send in bulk every N seconds instead of 1 HTTP call per log
- **Queue prioritization:** Orders before snapshots before logs
- **Retry with backoff:** Failed requests re-queued with exponential delay
- **Authentication management:** Single auth context, auto re-authenticate on 401

**Flow diagram:**

```
EA Thread                          HorizonAPI-Connector Thread
    │                                        │
    │  MessageBus.Send("connector",          │
    │    {type: "upsert_order", ...})        │
    │  ── write file + set GVar ──>          │
    │  (returns immediately, <1ms)           │
    │                                        │
    │  continues trading...                  │  Poll GVar (changed?)
    │                                        │  ── yes ──>
    │                                        │  Read message files
    │                                        │  Sort by priority
    │                                        │  │
    │                                        │  ├─ WebRequest POST /order/
    │                                        │  ├─ WebRequest POST /log/ (batch)
    │                                        │  └─ WebRequest POST /snapshot/
    │                                        │
    │                                        │  Delete processed messages
    │                                        │  Reset GVar
```

### Service 2: HorizonPersistence

**File:** `HorizonPersistence.mq5`

**Responsibility:** ALL file I/O operations (SEDb flush, state persistence, statistics, report exports).

**Consumes messages from EA on channel `persistence`:**

| Message Type      | Payload                          | Original Blocking Call              |
| ----------------- | -------------------------------- | ----------------------------------- |
| `save_order`      | Order JSON document              | `SRPersistenceOfOrders.SaveOrder()` |
| `set_state`       | strategyPrefix, key, type, value | `SRPersistenceOfState.SetXxx()`     |
| `save_statistics` | strategyPrefix, statistics JSON  | `SRPersistenceOfStatistics.Save()`  |
| `export_logs`     | log entries array                | `SRReportOfLogs.Export()`           |

**Internal optimizations:**

- **Write debouncing:** If 5 order changes arrive in 1 second, flush once (not 5 times)
- **State coalescing:** Multiple `SetXxx` calls for the same strategy merge into one flush
- **Batch window:** Accumulate changes for 500ms before flushing to disk

**Flow diagram:**

```
EA Thread                          HorizonPersistence Thread
    │                                        │
    │  OnTradeTransaction:                   │
    │  order status changes                  │
    │                                        │
    │  MessageBus.Send("persistence",        │
    │    {type: "save_order",                │
    │     path: "Live/XAUUSD/SYD",           │
    │     document: {...order JSON...}})      │
    │  ── write file + set GVar ──>          │
    │  (returns immediately, <1ms)           │
    │                                        │
    │  Strategy state changes:               │
    │  MessageBus.Send("persistence",        │
    │    {type: "set_state",                 │
    │     prefix: "SYD",                     │
    │     key: "lastTradeDay",               │
    │     valueType: "int",                  │
    │     value: "42"})                      │
    │  ── write file + set GVar ──>          │
    │                                        │
    │                                        │  Poll GVar (changed?)
    │                                        │  ── yes ──>
    │                                        │  Read all pending messages
    │                                        │  Group by target file
    │                                        │  │
    │                                        │  ├─ Load orders.json
    │                                        │  │  Apply 3 pending changes
    │                                        │  │  Flush once
    │                                        │  │
    │                                        │  ├─ Load state.json
    │                                        │  │  Apply 2 pending changes
    │                                        │  │  Flush once
    │                                        │  │
    │                                        │  Delete processed messages
```

### Service 3: HorizonAPI-Events

**File:** `HorizonAPIEvents.mq5`

**Responsibility:** Bidirectional event processing between the remote HorizonAPI and the local MT5 terminal.

This replaces the current `HorizonAPI.mq5` service with enhanced capabilities:

**Direction 1 — Inbound (Remote API -> MT5):**

- Poll `ConsumeEvents()` for incoming commands
- Process events that the service can handle directly (account info, ticker, klines)
- Forward events that require EA action via MessageBus

**Direction 2 — Outbound (MT5 -> Remote API):**

- EA sends event responses back through MessageBus
- Service sends `AckEvent()` responses

**Consumes messages from EA on channel `events`:**

| Message Type       | Payload                  | Purpose                                              |
| ------------------ | ------------------------ | ---------------------------------------------------- |
| `event_response`   | eventId, response JSON   | EA responds to an event that required trading action |
| `subscribe_events` | event keys to listen for | EA tells service which events to poll                |

**Sends messages to EA on channel `events_inbound`:**

| Message Type   | Payload                             | Purpose                           |
| -------------- | ----------------------------------- | --------------------------------- |
| `post_order`   | symbol, type, volume, price, sl, tp | Remote request to open an order   |
| `delete_order` | orderId                             | Remote request to close an order  |
| `put_order`    | orderId, sl, tp                     | Remote request to modify an order |
| `get_orders`   | symbol, side, status                | Remote request for order list     |

**Flow diagram — Bidirectional:**

```
Remote HorizonAPI Server
    │              ▲
    │ Consume      │ Ack
    ▼              │
┌──────────────────────────────────────────────────┐
│              HorizonAPI-Events Thread             │
│                                                  │
│  Loop (every 3s):                                │
│  │                                               │
│  ├── ConsumeEvents("get.account.info")           │
│  │   └── Handle directly (no EA needed)          │
│  │       └── AckEvent(response)                  │
│  │                                               │
│  ├── ConsumeEvents("get.ticker")                 │
│  │   └── Handle directly (SymbolInfoDouble)      │
│  │       └── AckEvent(response)                  │
│  │                                               │
│  ├── ConsumeEvents("get.klines")                 │
│  │   └── Handle directly (CopyRates + upload)    │
│  │       └── AckEvent(response)                  │
│  │                                               │
│  ├── ConsumeEvents("post.order")                 │
│  │   └── Forward to EA via MessageBus            │
│  │       └── MessageBus.Send("events_inbound",   │
│  │             {type:"post_order", ...})          │
│  │                                               │
│  ├── ConsumeEvents("delete.order")               │
│  │   └── Forward to EA via MessageBus            │
│  │                                               │
│  ├── ConsumeEvents("put.order")                  │
│  │   └── Forward to EA via MessageBus            │
│  │                                               │
│  └── Poll MessageBus("events") for EA responses  │
│      └── AckEvent(eventId, response)             │
│                                                  │
└──────────────────────────────────────────────────┘
    │                              ▲
    │ "events_inbound"             │ "events"
    │ channel                      │ channel
    ▼                              │
┌──────────────────────────────────────────────────┐
│                  Horizon.mq5 (EA)                 │
│                                                  │
│  OnTimer:                                        │
│  ├── MessageBus.Poll("events_inbound")           │
│  │   ├── post.order  → Execute trade             │
│  │   ├── delete.order → Close position           │
│  │   ├── put.order → Modify order                │
│  │   └── get.orders → Collect & respond          │
│  │                                               │
│  └── MessageBus.Send("events",                   │
│        {type:"event_response",                   │
│         eventId: "...",                           │
│         response: {...}})                         │
└──────────────────────────────────────────────────┘
```

---

## MessageBus (IPC Layer)

### Mechanism: GlobalVariables + FILE_COMMON

Native MQL5, no DLL required. Two components:

1. **GlobalVariable** — Signal flag (near-zero cost to read/write)
2. **FILE_COMMON file** — Message payload

### File Structure

```
%COMMON%/Horizon/
└── Messages/
    ├── connector/
    │   ├── 1710547200001.json    (pending message)
    │   ├── 1710547200042.json    (pending message)
    │   └── ...
    ├── persistence/
    │   ├── 1710547200003.json
    │   └── ...
    ├── events/
    │   └── ...
    └── events_inbound/
        └── ...
```

### Message Format

```json
{
  "type": "upsert_order",
  "timestamp": 1710547200001,
  "payload": {
    "id": "uuid-here",
    "account_id": 12345,
    "symbol": "XAUUSD",
    "side": "buy",
    "status": "open",
    "volume": 0.01
  }
}
```

### GlobalVariable Naming

| Variable                    | Purpose                                 | Set by            | Read by              |
| --------------------------- | --------------------------------------- | ----------------- | -------------------- |
| `HORIZON_CH_connector`      | Message counter for connector channel   | EA                | HorizonAPI-Connector |
| `HORIZON_CH_persistence`    | Message counter for persistence channel | EA                | HorizonPersistence   |
| `HORIZON_CH_events`         | Message counter for events channel      | EA                | HorizonAPI-Events    |
| `HORIZON_CH_events_inbound` | Message counter for inbound events      | HorizonAPI-Events | EA                   |

### Send Operation (EA side, <1ms)

```
1. Serialize payload to JSON string
2. Generate filename: {GetMicrosecondCount()}.json
3. FileOpen(FILE_COMMON) + FileWriteString + FileClose
4. GlobalVariableSet("HORIZON_CH_{channel}", counter + 1)
```

### Poll Operation (Service side)

```
1. GlobalVariableGet("HORIZON_CH_{channel}") — check if counter changed
2. If unchanged → return (no work)
3. If changed → scan directory for .json files
4. Sort by filename (timestamp order)
5. Read each file, parse, process
6. Delete processed files
7. Update local counter
```

### API

```
class SEMessageBus {
    // Send a message to a channel (non-blocking, <1ms)
    static bool Send(string channel, string messageType, string payloadJson);

    // Poll a channel for new messages (returns count)
    static int Poll(string channel, SMessage &messages[]);

    // Clean up old/orphaned messages on startup
    static void Cleanup(string channel);
};
```

---

## Service Responsibility Matrix

| Operation                  | Before (EA thread)         | After (which service)            | IPC Pattern      |
| -------------------------- | -------------------------- | -------------------------------- | ---------------- |
| `UpsertAccount()`          | EA blocks ~5s              | **Connector**                    | Fire-and-forget  |
| `FetchAccount()`           | EA blocks ~5s              | **EA** (OnInit only, acceptable) | Direct call      |
| `UpsertStrategy()`         | EA blocks ~5s per strategy | **Connector**                    | Fire-and-forget  |
| `UpsertOrder()`            | EA blocks ~5s per order    | **Connector**                    | Fire-and-forget  |
| `StoreLog()`               | EA blocks ~5s per log      | **Connector** (batched)          | Fire-and-forget  |
| `StoreHeartbeat()`         | EA blocks ~5s per strategy | **Connector**                    | Fire-and-forget  |
| `StoreAccountSnapshot()`   | EA blocks ~5s              | **Connector**                    | Fire-and-forget  |
| `StoreStrategySnapshot()`  | EA blocks ~5s per strategy | **Connector**                    | Fire-and-forget  |
| `SaveOrder()` (file)       | EA blocks ~500ms           | **Persistence**                  | Fire-and-forget  |
| `SetState*()` (file)       | EA blocks ~500ms per call  | **Persistence** (coalesced)      | Fire-and-forget  |
| `Save()` statistics (file) | EA blocks ~500ms           | **Persistence**                  | Fire-and-forget  |
| `Export()` logs (file)     | EA blocks ~1s              | **Persistence**                  | Fire-and-forget  |
| `ConsumeEvents()`          | Already in service         | **Events**                       | N/A              |
| `AckEvent()`               | Already in service         | **Events**                       | N/A              |
| `post.order` event         | N/A (service handled)      | **Events** -> EA -> **Events**   | Request-Response |
| `delete.order` event       | N/A (service handled)      | **Events** -> EA -> **Events**   | Request-Response |
| `put.order` event          | N/A (service handled)      | **Events** -> EA -> **Events**   | Request-Response |
| `get.orders` event         | N/A (new)                  | **Events** -> EA -> **Events**   | Request-Response |
| `get.account.info` event   | Already in service         | **Events** (direct)              | N/A              |
| `get.ticker` event         | Already in service         | **Events** (direct)              | N/A              |
| `get.klines` event         | Already in service         | **Events** (direct)              | N/A              |

---

## Complete System Diagram

```
                        ┌─────────────────────┐
                        │  Remote HorizonAPI   │
                        │  Server              │
                        └───▲────────────┬─────┘
                            │            │
                    HTTP POST/PATCH   HTTP POST
                   (Ack, Upload)    (Consume)
                            │            │
┌───────────────────────────┼────────────┼──────────────────────────┐
│ MetaTrader 5 Terminal     │            │                          │
│                           │            │                          │
│  ┌────────────────────────┴────────────▼───────────────────────┐  │
│  │              HorizonAPI-Events (Service 3)                  │  │
│  │              Thread: own                                    │  │
│  │                                                             │  │
│  │  Inbound:                    Outbound:                      │  │
│  │  ConsumeEvents() ──┐         ┌── AckEvent()                 │  │
│  │                    │         │                              │  │
│  │  Self-handled:     │         │  EA-forwarded:               │  │
│  │  - account.info    │         │  - post.order                │  │
│  │  - ticker          │         │  - delete.order              │  │
│  │  - klines          │         │  - put.order                 │  │
│  │                    │         │  - get.orders                │  │
│  └────────────────────┼─────────┼──────────────────────────────┘  │
│            events_inbound │     │ events                          │
│              channel  ▼   │     │  channel  ▲                     │
│                       │   │     │           │                     │
│  ┌────────────────────┼───┼─────┼───────────┼──────────────────┐  │
│  │                    │   │     │           │                  │  │
│  │                Horizon.mq5 (EA)                             │  │
│  │                Thread: main chart                           │  │
│  │                                                             │  │
│  │  OnTimer:                                                   │  │
│  │  ├── Strategy evaluation          (fast, no I/O)            │  │
│  │  ├── Order management             (fast, no I/O)            │  │
│  │  ├── MessageBus.Poll("events_inbound")  (<1ms)              │  │
│  │  │   └── Process trading events from remote                 │  │
│  │  └── MessageBus.Send("connector", sync data)  (<1ms)        │  │
│  │                                                             │  │
│  │  OnTradeTransaction:                                        │  │
│  │  ├── MessageBus.Send("connector", order upsert)  (<1ms)     │  │
│  │  └── MessageBus.Send("persistence", save order)  (<1ms)     │  │
│  │                                                             │  │
│  │  Logger:                                                    │  │
│  │  └── MessageBus.Send("connector", store log)  (<1ms)        │  │
│  │                                                             │  │
│  └──────┬─────────────────────────────────┬────────────────────┘  │
│         │ connector                       │ persistence           │
│         │ channel                         │ channel               │
│         ▼                                 ▼                       │
│  ┌──────────────────────┐  ┌──────────────────────────────────┐   │
│  │  HorizonAPI-Connector│  │  HorizonPersistence              │   │
│  │  (Service 1)         │  │  (Service 2)                     │   │
│  │  Thread: own         │  │  Thread: own                     │   │
│  │                      │  │                                  │   │
│  │  Queue:              │  │  Queue:                          │   │
│  │  ├─ UpsertAccount    │  │  ├─ SaveOrder (debounced)        │   │
│  │  ├─ UpsertStrategy   │  │  ├─ SetState (coalesced)         │   │
│  │  ├─ UpsertOrder      │  │  ├─ SaveStatistics               │   │
│  │  ├─ StoreLog (batch) │  │  └─ ExportLogs                   │   │
│  │  ├─ StoreHeartbeat   │  │                                  │   │
│  │  ├─ StoreAccSnapshot │  │  Optimizations:                  │   │
│  │  └─ StoreStrSnapshot │  │  - Debounce: 500ms window        │   │
│  │                      │  │  - Coalesce: N changes = 1 flush  │   │
│  │  Optimizations:      │  │                                  │   │
│  │  - Log batching      │  └──────────────────────────────────┘   │
│  │  - Priority queue    │                                         │
│  │  - Retry + backoff   │         IPC Mechanism:                  │
│  │  - Auto re-auth      │         GlobalVariableSet/Get (signal)  │
│  └──────────────────────┘         FILE_COMMON .json (payload)     │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: MessageBus (Foundation)

Create the shared IPC layer used by all services and the EA.

**New files:**

- `services/SEMessageBus/SEMessageBus.mqh` — Core Send/Poll/Cleanup
- `services/SEMessageBus/SEMessageChannel.mqh` — Channel abstraction
- `services/SEMessageBus/structs/SMessage.mqh` — Message struct

**Dependencies:** None (uses native MQL5 GlobalVariable + FILE_COMMON)

### Phase 2: HorizonAPI-Connector (Service 1)

Move all outbound HTTP calls from the EA to this service.

**New files:**

- `HorizonAPIConnector.mq5` — Service entry point

**Modified files:**

- `Horizon.mq5` — Replace direct `horizonAPI.*` calls with `MessageBus.Send("connector", ...)`
- `assets/Asset.mqh` — Replace `SyncToHorizonAPI()` internals
- `strategies/Strategy.mqh` — Replace `UpsertOrder()` calls in `OnOpenOrder`, `OnCloseOrder`, `OnCancelOrder`, `SyncSnapshot`
- `services/SELogger/SELogger.mqh` — Replace `sendToRemote()` with `MessageBus.Send`

**HorizonAPI integration reuse:** This service includes `integrations/HorizonAPI/HorizonAPI.mqh` directly (same as EA does today). No changes needed to the integration layer itself.

### Phase 3: HorizonPersistence (Service 2)

Move all file I/O from the EA to this service.

**New files:**

- `HorizonPersistence.mq5` — Service entry point

**Modified files:**

- `services/SRPersistenceOfOrders/SRPersistenceOfOrders.mqh` — Add `EnqueueSave()` that uses MessageBus instead of direct Flush
- `services/SRPersistenceOfState/SRPersistenceOfState.mqh` — Add `EnqueueSet()` variants
- `services/SRPersistenceOfStatistics/SRPersistenceOfStatistics.mqh` — Add `EnqueueSave()`
- `services/SEDb/SEDbCollection.mqh` — No changes (service uses it directly)

### Phase 4: HorizonAPI-Events (Service 3)

Evolve the current `HorizonAPI.mq5` into a bidirectional event processor.

**Modified files:**

- `HorizonAPI.mq5` → rename to `HorizonAPIEvents.mq5`
- Add `MessageBus.Send("events_inbound", ...)` for events requiring EA action
- Add `MessageBus.Poll("events")` for EA responses
- Remove `HorizonAPI` class usage for outbound sync (that is now in Connector)

**Modified files (EA side):**

- `Horizon.mq5` — Add `MessageBus.Poll("events_inbound")` in OnTimer to receive trading commands from remote

### Phase 5: Testing and Validation

- Verify message delivery under load (simulate rapid order changes)
- Verify no message loss on service restart (messages persist as files until processed)
- Verify correct ordering of operations
- Verify debouncing/batching works as expected
- Measure actual latency reduction in EA thread

---

## Risk Analysis

| Risk                                       | Impact                                                 | Mitigation                                                             |
| ------------------------------------------ | ------------------------------------------------------ | ---------------------------------------------------------------------- |
| Service not running when EA sends messages | Messages queue as files, processed when service starts | Acceptable — files persist                                             |
| Message loss (file deleted before read)    | Order/state not persisted                              | Service reads then deletes atomically                                  |
| Service crash mid-processing               | Partial state                                          | Process messages one at a time, delete only after success              |
| GlobalVariable limit (~4096)               | Signal mechanism breaks                                | Only 4 GVars used (one per channel), counter-based                     |
| FILE_COMMON disk space                     | Unprocessed messages accumulate                        | Cleanup on startup, TTL on old messages                                |
| Order of operations                        | State depends on order data                            | Same service (Persistence) handles both, processes in order            |
| `FetchAccount()` still blocking in OnInit  | EA init delayed ~5s                                    | Acceptable — happens once at startup, needed for active/inactive check |

---

## File Map Summary

| File                                                               | Status          | Service                      |
| ------------------------------------------------------------------ | --------------- | ---------------------------- |
| `services/SEMessageBus/SEMessageBus.mqh`                           | NEW             | Shared                       |
| `services/SEMessageBus/SEMessageChannel.mqh`                       | NEW             | Shared                       |
| `services/SEMessageBus/structs/SMessage.mqh`                       | NEW             | Shared                       |
| `HorizonAPIConnector.mq5`                                          | NEW             | Service 1                    |
| `HorizonPersistence.mq5`                                           | NEW             | Service 2                    |
| `HorizonAPI.mq5` → `HorizonAPIEvents.mq5`                          | RENAME + MODIFY | Service 3                    |
| `Horizon.mq5`                                                      | MODIFY          | EA                           |
| `assets/Asset.mqh`                                                 | MODIFY          | EA                           |
| `strategies/Strategy.mqh`                                          | MODIFY          | EA                           |
| `services/SELogger/SELogger.mqh`                                   | MODIFY          | EA                           |
| `services/SRPersistenceOfOrders/SRPersistenceOfOrders.mqh`         | MODIFY          | EA                           |
| `services/SRPersistenceOfState/SRPersistenceOfState.mqh`           | MODIFY          | EA                           |
| `services/SRPersistenceOfStatistics/SRPersistenceOfStatistics.mqh` | MODIFY          | EA                           |
| `integrations/HorizonAPI/HorizonAPI.mqh`                           | NO CHANGES      | Reused by Connector + Events |
