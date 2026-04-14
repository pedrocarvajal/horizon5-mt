# CLAUDE.md

# Rules

- On every `.mq5` file modification, bump `#property version`. The project is currently in unstable pre-release (`0.x`). Versioning scheme:
  - `Horizon.mq5`: `0.{total project commit count}` (e.g. `0.340` means 340 commits across the project)
  - Service files (`HorizonGateway.mq5`, `HorizonMonitor.mq5`, `HorizonPersistence.mq5`): `0.{commit count for that specific file}` (e.g. `0.05` means 5 commits touching that file)
  - When the project reaches stable release, MAJOR will move to `1` and versioning will switch to `MAJOR.MINORPATCH` format (e.g. `1.00`, `1.01`, `1.10`): MAJOR for breaking changes, MINOR (tens digit) for new functionality, PATCH (ones digit) for fixes or non-functional changes.
  - This does not apply to `.mqh` files. Update the version before committing/pushing changes.

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
