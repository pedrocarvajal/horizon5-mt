# Installation

## Requirements

- MetaTrader 5 Terminal (build 4000+)
- MetaEditor (included with MetaTrader 5)
- Windows OS (required by MetaTrader 5)

## Clone the repository

Clone into your MetaTrader 5 data folder under `MQL5/Experts/`:

```
cd "<MT5 Data Folder>/MQL5/Experts"
git clone <repository-url> Horizon5
```

To find your data folder, open MetaTrader 5 and go to **File > Open Data Folder**.

## Compile

Open MetaEditor and compile the following files in order.

### Main Expert Advisor (required)

Compile `Horizon.mq5`. This is the core EA that runs all strategies, manages orders, and coordinates the portfolio.

### Companion services

These are MT5 services (background processes) that run alongside the EA:

| File                     | Required           | Purpose                                                                                                                                          |
| ------------------------ | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `HorizonPersistence.mq5` | Yes (live trading) | Handles file I/O asynchronously via the MessageBus. Offloads disk writes from the EA's main thread.                                              |
| `HorizonMonitor.mq5`     | No                 | Forwards snapshots, orders, and logs to the Horizon API for monitoring. Requires a running Horizon API instance.                                 |
| `HorizonGateway.mq5`     | No                 | Enables remote order management by consuming events from the Horizon API and forwarding them to the EA. Requires a running Horizon API instance. |

## Attach the EA

1. Drag `Horizon5/Horizon` onto any chart in MetaTrader 5 (the chart symbol does not matter -- the EA manages multiple symbols internally).
2. In the EA properties dialog, enable **Allow DLL imports** (required for the MessageBus library).
3. If using Monitor or Gateway, add the Horizon API domain to **Tools > Options > Expert Advisors > Allow WebRequest for listed URL**.

## Configure input parameters

The EA exposes five input groups:

### General Settings

- **Tick interval** -- polling interval in seconds (default: 60).
- **Order filling mode** -- broker-dependent fill policy (IOC, FOK, or Return).
- **Debug log level** -- controls verbosity of log output.

### Reporting

- **Enable order history report** -- generates an order history CSV during backtests.
- **Enable snapshot history report** -- generates strategy snapshot CSVs during backtests.
- **Enable market history report** -- generates market data CSVs during backtests.

### Risk Management

- **Equity at risk compounded** -- whether to compound position sizing based on current equity.
- **Equity at risk value** -- maximum percentage of equity risked per trade (default: 1%).

### Horizon Monitor

- **Enable Horizon integration** -- toggle the Monitor integration on or off.
- **HorizonMonitor base URL** -- the root URL of the Horizon API instance (e.g. `https://api.example.com`).
- **Email / Password** -- credentials for API authentication.

### Horizon Gateway

- **HorizonGateway base URL** -- the root URL of the Gateway API instance.
- **Email / Password** -- credentials for API authentication.

The Gateway and Monitor services have their own input parameters when started as MT5 services (URL, email, password, debug level). These must match the values configured in the EA.

## Strategy toggles

Each asset file exposes individual `input bool` toggles to enable or disable strategies. These appear in the EA properties dialog grouped by instrument (e.g. `[Gold] Strategies >`, `[SP500] Strategies >`). Enable only the strategies you want to run.
