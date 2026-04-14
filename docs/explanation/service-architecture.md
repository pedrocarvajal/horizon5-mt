# Service Architecture

## The problem: single-threaded execution

MetaTrader 5 runs Expert Advisors on a single thread. Any blocking operation -- HTTP requests, file writes, long computations -- freezes the EA and delays trade processing. In a live trading environment where order fills and price ticks arrive asynchronously, even a 200ms HTTP call can cause missed events.

## The solution: service scripts and a message bus

Horizon5 splits blocking I/O into separate `.mq5` service scripts that run as independent MT5 services. The EA and its services communicate through a shared-memory message bus backed by a custom DLL (`HorizonMessageBus`).

Each service runs its own polling loop, reads messages from assigned channels, performs the blocking work, and acknowledges completion. The EA never blocks on I/O.

## Message bus channels

The message bus defines five named channels (in `constants/COMessageBus.mqh`):

| Channel           | Constant                    | Direction                 | Purpose                                                         |
| ----------------- | --------------------------- | ------------------------- | --------------------------------------------------------------- |
| `connector`       | `MB_CHANNEL_CONNECTOR`      | EA -> Monitor service     | HTTP POST requests for the Monitor API                          |
| `persistence`     | `MB_CHANNEL_PERSISTENCE`    | EA -> Persistence service | File write requests (JSON order state, statistics)              |
| `events_inbound`  | `MB_CHANNEL_EVENTS_IN`      | Gateway service -> EA     | Trading events from the API (post/delete/put/get orders)        |
| `events_outbound` | `MB_CHANNEL_EVENTS_OUT`     | EA -> Gateway service     | Acknowledgment responses back to the API                        |
| `events_service`  | `MB_CHANNEL_EVENTS_SERVICE` | Gateway service -> EA     | Service-level events (account info, asset queries, ticker data) |

Each message carries a `messageType` string and a JSON payload. The bus assigns a monotonic sequence number to every published message, enabling acknowledgment-based flow control.

## Service registration and health monitoring

Each service registers itself on startup:

- **HorizonPersistence** registers as `MB_SERVICE_PERSISTENCE`
- **HorizonGateway** registers as `MB_SERVICE_GATEWAY`
- **HorizonMonitor** registers as `MB_SERVICE_MONITOR`

On initialization, the EA calls `InitializeMessageBus()` which checks that all required services are running via `SEMessageBus::AreServicesReady()`. If any required service is missing, the EA refuses to start.

During runtime, the EA calls `CheckServiceHealth()` every minute. If required services go down, trading is paused (`TRADING_PAUSE_REASON_SERVICES_DOWN`) and the message bus is shut down. When services recover, trading resumes automatically.

## HorizonPersistence

Always required in live trading. Polls the `persistence` channel every 200ms (configurable via `PollIntervalMs`). Receives file write requests from the EA -- primarily JSON-serialized order state and statistics.

Key behavior: **deduplication**. When multiple writes target the same file path within a single poll cycle, only the latest content is written. Earlier messages for that path are acknowledged without writing, reducing disk I/O when order state changes rapidly.

The service also ensures target directories exist before writing and logs queue diagnostics every 5 minutes.

## HorizonGateway

Optional. Only starts when Gateway URL and credentials are configured and the EA runs in live mode. Polls the Horizon API every 3 seconds (`EVENT_POLL_INTERVAL_SECONDS`) for pending events.

The service handles two categories of events:

- **Trading events** (`post.order`, `delete.order`, `put.order`, `get.orders`): forwarded to the EA via `MB_CHANNEL_EVENTS_IN` for order management.
- **Service events** (`get.account.info`, `get.assets`, `get.strategies`, `get.ticker`, `get.klines`, `patch.account.disable`, `patch.account.enable`): forwarded via `MB_CHANNEL_EVENTS_SERVICE` for informational responses.

The EA processes inbound trading events through `SEGateway` (per asset), which dispatches to specific handlers (`HHandlePostOrder`, `HHandleDeleteOrder`, etc.). Acknowledgments flow back through `MB_CHANNEL_EVENTS_OUT`.

## HorizonMonitor

Optional. Forwards HTTP POST requests from the EA to the Horizon Monitor API. Polls `MB_CHANNEL_CONNECTOR` every 100ms. Prioritizes order-related endpoints over other requests to minimize latency on trade state synchronization.

The Monitor service processes requests containing a `path` and JSON body, executes the HTTP POST, and acknowledges the message. It does not return response data to the EA -- monitoring is fire-and-forget.
