# Installation

## Requirements

- MetaTrader 5 Terminal (build 4000+).
- MetaEditor (bundled with MetaTrader 5).
- Windows (required by MetaTrader 5).

## Clone the repository

Clone into your MetaTrader 5 data folder, under `MQL5/Experts/`:

```
cd "<MT5 Data Folder>/MQL5/Experts"
git clone <repository-url> Horizon5
```

To locate your data folder, open MetaTrader 5 and go to **File > Open Data Folder**.

## Compile

Open MetaEditor and compile, in this order:

### Main Expert Advisor (required)

Compile `Horizon.mq5`. This is the core EA: it owns the portfolio, dispatches events, routes trade transactions, and coordinates services.

### Service scripts

Each service is a standalone `.mq5` file that runs as an MT5 service alongside the EA and communicates with it through the message bus.

| File                     | Required for live trading | Purpose                                                                         |
| ------------------------ | ------------------------- | ------------------------------------------------------------------------------- |
| `HorizonPersistence.mq5` | Yes                       | Asynchronous file I/O for order state, statistics, and strategy key/value state |
| `HorizonMonitor.mq5`     | Optional                  | Pushes telemetry (account, assets, strategies, orders, logs, snapshots) outward |
| `HorizonGateway.mq5`     | Optional                  | Consumes remote trading and service events and forwards them to the EA          |

`HorizonMonitor` and `HorizonGateway` both depend on external backend services that are part of the private ecosystem — see [Ecosystem](../../README.md#ecosystem). If you don't have access, leave them disabled.

## Attach the EA

1. Drag `Horizon5/Horizon` onto any chart. The chart symbol is irrelevant — the EA manages all its own symbols internally.
2. In the EA properties dialog, enable **Allow DLL imports** (required by the message bus).
3. If using Monitor or Gateway, add the corresponding backend domain to **Tools > Options > Expert Advisors > Allow WebRequest for listed URL**.

## Configure input parameters

Inputs are grouped; see [Reference > Configuration](../reference/configuration.md) for the exhaustive list. The main groups are:

- **General Settings** — tick interval, order filling mode, debug level.
- **Reporting > Strategy Reports** — per-strategy order/snapshot/market exports for backtests.
- **Reporting > Monitor Seed** — dataset seeding for external monitoring (backtests).
- **Reporting > Logs** — portfolio log export on shutdown.
- **Risk management** — equity-at-risk percentage and compounding toggle.
- **Horizon Monitor** — enable flag and credentials for the optional Monitor integration.
- **Horizon Gateway** — enable flag and credentials for the optional Gateway integration.

## Enable strategies

Each asset file exposes individual `input bool` toggles for its strategies. They appear in the EA dialog grouped by instrument. An asset is considered enabled when at least one of its strategies is toggled on; assets with no enabled strategies are silently skipped.
