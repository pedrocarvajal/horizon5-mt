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

Open MetaEditor and compile `Horizon.mq5`. It is the only program you need to compile: the core EA that owns the portfolio, dispatches events, routes trade transactions, and coordinates services.

## Attach the EA

Drag `Horizon5/Horizon` onto any chart. The chart symbol is irrelevant — the EA manages all its own symbols internally. No DLL imports, WebRequest URLs, or companion MT5 services are required.

## Configure input parameters

Inputs are grouped; see [Reference > Configuration](../reference/configuration.md) for the exhaustive list. The main groups are:

- **General Settings** — tick interval, order filling mode, debug level.
- **Reporting > Strategy Reports** — per-strategy order/snapshot/market exports for backtests.
- **Reporting > Logs** — portfolio log export on shutdown.
- **Risk management** — equity-at-risk percentage and compounding toggle.

## Enable strategies

Each asset file exposes individual `input bool` toggles for its strategies. They appear in the EA dialog grouped by instrument. An asset is considered enabled when at least one of its strategies is toggled on; assets with no enabled strategies are silently skipped.
