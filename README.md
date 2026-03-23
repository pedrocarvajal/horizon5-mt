# Horizon5

![MQL5](https://img.shields.io/badge/MQL5-MetaTrader%205-blue.svg)
![Platform](https://img.shields.io/badge/platform-windows-lightgrey.svg)
![License](https://img.shields.io/badge/license-PolyForm%20Noncommercial-orange.svg)

A portfolio-based algorithmic trading framework for MetaTrader 5. Build, backtest, and deploy multiple trading strategies across different assets with event-driven architecture, risk-adjusted position sizing, and optional remote integrations.

## Overview

Horizon5 uses a hierarchical portfolio pattern where the Expert Advisor manages multiple assets, each containing independent strategies that generate signals and manage orders. Capital is allocated equally across enabled assets, then split equally among each asset's active strategies.

```text
Horizon.mq5 --> SEAsset[] --> SEStrategy[] --> EOrder[]
```

## Key Features

- **Multi-asset portfolio** -- Trade Gold, Bitcoin, SP500, Nikkei225 (or add your own) from a single EA
- **Event-driven architecture** -- Timer-based system with day, hour, and minute transitions propagated down the hierarchy
- **Risk-adjusted position sizing** -- ATR-based dynamic stops with configurable equity-at-risk percentage
- **Order state machine** -- Full lifecycle (PENDING, OPEN, CLOSING, CLOSED) with JSON persistence for live trading recovery
- **Performance tracking** -- NAV, drawdown, quality metrics per strategy
- **Message bus IPC** -- DLL-based inter-process communication between the EA and companion services
- **Remote integrations** -- Optional Gateway (remote order management) and Monitor (observability) via Horizon API
- **Persistence service** -- Async file writer for order and state recovery across EA restarts

## Quick Start

1. Clone into your MetaTrader 5 Experts folder:

```bash
git clone <repo-url> /path/to/MetaTrader5/MQL5/Experts/Horizon5/
```

2. Open `Horizon.mq5` in MetaEditor and compile
3. Attach the Expert Advisor to any chart
4. Enable strategies via the input parameters panel

For companion services setup and full configuration, see [Installation Guide](docs/getting-started/installation.md).

## Architecture

```text
+------------------+      +---------------------+
|   Horizon.mq5    |      | HorizonPersistence  |
|   (Expert Advisor) <---->  (Service .mq5)     |
|                  |  MB  |  Async file writer   |
|  Assets[]        |      +---------------------+
|   Strategies[]   |
|    Orders[]      |      +---------------------+
|                  | MB   | HorizonGateway       |
|  Event loop      <-----> (Service .mq5)       |
|  Risk management |      |  Remote order sync   |
|  Statistics      |      +---------------------+
|                  |
|                  |      +---------------------+
|                  | MB   | HorizonMonitor       |
|                  <-----> (Service .mq5)       |
+------------------+      |  Monitoring push     |
                          +---------------------+
       MB = MessageBus (DLL-based IPC)
```

The EA runs as the main process. Three companion services run as separate `.mq5` service scripts, communicating through a shared message bus:

| Service     | File                     | Required     | Purpose                                                 |
| ----------- | ------------------------ | ------------ | ------------------------------------------------------- |
| Persistence | `HorizonPersistence.mq5` | Live trading | Async file writer for order/state recovery              |
| Gateway     | `HorizonGateway.mq5`     | Optional     | Event bridge to Horizon API for remote order management |
| Monitor     | `HorizonMonitor.mq5`     | Optional     | Pushes account/strategy data to monitoring dashboard    |

Gateway and Monitor require a running [Horizon API](https://github.com/pedrocarvajal/horizon5-mt-api) instance. If you don't use the Horizon API, leave these services disabled.

For details on the service architecture and message bus, see [Service Architecture](docs/explanation/service-architecture.md).

## Project Structure

```text
horizon5-portfolio/
+-- Horizon.mq5                     Main Expert Advisor
+-- HorizonGateway.mq5              Gateway service (optional)
+-- HorizonMonitor.mq5              Monitor service (optional)
+-- HorizonPersistence.mq5          Persistence service (live trading)
+-- adapters/                       Trade execution adapter (CTrade wrapper)
+-- assets/                         Asset definitions by class
|   +-- Commodities/Gold.mqh        Gold (XAUUSD) - 10 strategies
|   +-- Crypto/Bitcoin.mqh          Bitcoin (BTCUSD)
|   +-- Indices/SP500.mqh           S&P 500 (US500) - 10 strategies
|   +-- Indices/Nikkei225.mqh       Nikkei 225 - 10 strategies
+-- configs/                        Asset registry
+-- constants/                      Time constants
+-- entities/                       Domain entities (Account, Asset, Order)
+-- enums/                          Enumerations (statuses, debug levels)
+-- helpers/                        Utility functions (UUID, pip calc, market status)
+-- indicators/                     Market data functions (CopyXxx-based)
+-- integrations/                   External API integrations
|   +-- HorizonGateway/             Remote order management
|   +-- HorizonMonitor/             Monitoring data push
+-- interfaces/                     Abstract contracts (IAsset, IStrategy)
+-- libraries/                      External MQL5 libraries
+-- services/                       Business logic (20 services)
+-- strategies/                     Strategy implementations
|   +-- Strategy.mqh                SEStrategy base class
|   +-- Commodities/Gold/           Australian city names (Ballarat, Bendigo, ...)
|   +-- Indices/Nikkei225/          Japanese city names (Kyoto, Osaka, ...)
|   +-- Indices/SP500/              American city names (Austin, Denver, ...)
|   +-- Generic/                    Gateway and Test strategies
+-- structs/                        Data structures
+-- docs/                           Documentation
```

For a detailed breakdown, see [Project Structure](docs/getting-started/project-structure.md).

## Documentation

| Section                                  | Description                                            |
| ---------------------------------------- | ------------------------------------------------------ |
| [Getting Started](docs/getting-started/) | Installation, project structure, first strategy        |
| [How-To Guides](docs/how-to/)            | Add strategies, configure risk, go live                |
| [Reference](docs/reference/)             | Configuration, services, events, naming conventions    |
| [Explanation](docs/explanation/)         | Architecture decisions, order lifecycle, observability |

## Ecosystem

| Project                                                                   | Description                                                   |
| ------------------------------------------------------------------------- | ------------------------------------------------------------- |
| **Horizon EA** (this repo)                                                | MetaTrader 5 Expert Advisor                                   |
| [**Horizon API**](https://github.com/pedrocarvajal/horizon5-mt-api)       | Django REST API for persistence, events, and order management |
| [**Horizon War Room**](https://github.com/pedrocarvajal/horizon5-warroom) | Grafana-based monitoring dashboard                            |

## Project Status

This project is currently in **unstable pre-release** (version `0.x`). The API, architecture, and conventions may change without notice. Version `1.0` will mark the first stable release.

## About

Horizon5 is the codebase behind a personal live trading portfolio. I built it for my own use and I maintain it as long as I'm actively trading with it. Strategies are not published as they are proprietary intellectual property.

If you're interested in collaborating, building on this framework, or need support, feel free to reach out through my [GitHub profile](https://github.com/pedrocarvajal).

## Disclaimer

This software is provided for educational and research purposes. Algorithmic trading involves substantial risk of financial loss. Past performance does not guarantee future results. The authors are not responsible for any trading losses incurred through the use of this software. Always test thoroughly in a demo environment before deploying to live markets.

## License

This project is licensed under the PolyForm Noncommercial License. See [LICENSE.md](LICENSE.md) for details.
