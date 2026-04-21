# Service Architecture

## The problem: single-threaded execution

MetaTrader 5 runs every Expert Advisor on a single thread. Any blocking operation — HTTP calls, file writes, long computations — freezes the EA and delays trade processing. In a live environment where fills and ticks arrive asynchronously, even a 200ms HTTP timeout can cause missed events or stale order state.

## The solution: service scripts and a message bus

Horizon5 pushes blocking I/O out of the EA entirely. Each concern that can block is owned by a standalone `.mq5` **service script** that MT5 runs as an independent service. The EA and its services communicate through a shared-memory **message bus**, backed by a custom DLL (`HorizonMessageBus`).

Each service runs its own polling loop, reads messages from its assigned channels, performs the blocking work, and ACKs. The EA publishes fire-and-forget and never blocks on I/O.

## Message bus channels

Defined in `constants/COMessageBus.mqh`:

| Channel           | Constant                    | Direction                | Purpose                                                      |
| ----------------- | --------------------------- | ------------------------ | ------------------------------------------------------------ |
| `connector`       | `MB_CHANNEL_CONNECTOR`      | EA → Monitor service     | Outbound HTTP POST bodies for the Monitor backend            |
| `persistence`     | `MB_CHANNEL_PERSISTENCE`    | EA → Persistence service | File-write requests (JSON order state, statistics, state KV) |
| `events_inbound`  | `MB_CHANNEL_EVENTS_IN`      | Gateway service → EA     | Remote trading events (post/delete/put/get order)            |
| `events_outbound` | `MB_CHANNEL_EVENTS_OUT`     | EA → Gateway service     | ACK responses back to the Gateway backend                    |
| `events_service`  | `MB_CHANNEL_EVENTS_SERVICE` | Gateway service → EA     | Service-level queries (account info, assets, ticker, klines) |

Each message carries a `messageType` string and a JSON payload. The bus assigns a monotonic sequence number to every published message, enabling ACK-based flow control.

## Service registration and health supervision

On startup, each service registers itself:

- `HorizonPersistence.mq5` → `MB_SERVICE_PERSISTENCE`
- `HorizonGateway.mq5` → `MB_SERVICE_GATEWAY`
- `HorizonMonitor.mq5` → `MB_SERVICE_MONITOR`

On EA init, `InitializeMessageBus()` verifies that all required services are alive via `SEMessageBus::AreServicesReady()`. Missing required services block initialization.

During runtime, `CheckServiceHealth()` runs once a minute:

- If required services go down, trading is paused with `TRADING_PAUSE_REASON_SERVICES_DOWN` and the bus is shut down.
- When services recover, the bus reactivates and trading resumes automatically.

## HorizonPersistence

Always required in live trading. Polls `MB_CHANNEL_PERSISTENCE` every `PollIntervalMs` (default 200ms) and receives write requests — primarily JSON-serialized order state and statistics.

Key behavior: **deduplication**. When multiple writes target the same path within a single poll cycle, only the latest content is written. Earlier messages for that path are ACKed without writing. This keeps disk I/O bounded even when order state changes rapidly.

The service also ensures target directories exist before writing, and emits queue diagnostics on an interval.

## HorizonGateway

Optional. Only starts when URL and credentials are configured and the EA runs in live mode. Polls the Gateway backend every `EVENT_POLL_INTERVAL_SECONDS` (default 3s) for pending events.

Handles two categories:

- **Trading events** (`post.order`, `delete.order`, `put.order`, `get.orders`) — forwarded to the EA via `MB_CHANNEL_EVENTS_IN` for order management.
- **Service events** (`get.account.info`, `get.assets`, `get.strategies`, `get.ticker`, `get.klines`, `patch.account.disable`, `patch.account.enable`) — forwarded via `MB_CHANNEL_EVENTS_SERVICE`.

The EA processes inbound trading events through `SEGateway` (per asset), which dispatches to specific handlers. ACKs flow back through `MB_CHANNEL_EVENTS_OUT`.

## HorizonMonitor

Optional. Forwards outbound HTTP POSTs from the EA to the Monitor backend. Polls `MB_CHANNEL_CONNECTOR` frequently (default 100ms) and **prioritizes order-related endpoints** over general telemetry to minimize latency on trade-state synchronization.

Requests carry a `path` and a JSON body. The service executes the POST and ACKs the message — monitoring is fire-and-forget from the EA's perspective.
