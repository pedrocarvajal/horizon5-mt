# CLAUDE.md

# Rules

- On every commit / unit of work touching a `.mq5` file, bump its version via `make version-upgrade-<target>` (targets: `expert`, `gateway`, `monitor`, `persistence`, `all`; optional `KIND=counter|minor|patch`, default `counter`). Never hand-edit `#property version` or the `service started` log line. Example: `make version-upgrade-expert` after working on `Horizon.mq5`, or `make version-upgrade-all` if several `.mq5` files changed.

# Projects correlation

The Horizon ecosystem consists of several interconnected repositories.
All projects must stay in sync; when changes in one project affect another, notify the user.

## Core projects (upstream / source of truth)

| Project              | Path                                      | Description                                                                                                                                                       |
| -------------------- | ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Horizon EA**       | `/Users/memeonlymellc/horizon5-portfolio` | Main MetaTrader 5 Expert Advisor. This is the current repository.                                                                                                 |
| **Horizon Gateway**  | `/Users/memeonlymellc/horizon5-gateway`   | Backend counterpart of `HorizonGateway.mq5` (via `integrations/HorizonGateway/`). Handles trading and service events (orders, account info, assets, klines, etc). |
| **Horizon Monitor**  | `/Users/memeonlymellc/horizon5-monitor`   | Backend counterpart of `HorizonMonitor.mq5` (via `integrations/HorizonMonitor/`). Receives monitoring data pushed from the EA.                                    |
| **Horizon War Room** | `/Users/memeonlymellc/horizon5-warroom`   | Dashboard that consumes Horizon Monitor to visualize the ecosystem state.                                                                                         |
