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

| Project              | Path                                      | Description                                                                                                                                 |
| -------------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **Horizon EA**       | `/Users/memeonlymellc/horizon5-portfolio` | Main MetaTrader 5 Expert Advisor. This is the current repository.                                                                           |
| **Horizon API**      | `/Users/memeonlymellc/horizon5-mt-api`    | Django REST API that the EA communicates with via `integrations/HorizonAPI/`. Handles persistence, snapshots, events, and order management. |
| **Horizon War Room** | `/Users/memeonlymellc/horizon5-warroom`   | Monitoring dashboard that consumes the Horizon API.                                                                                         |

## Client forks (Enaria)

These are client-specific forks that must mirror the core projects, adding only client-specific configuration.

| Project           | Path                                                    | Upstream                                                                                                                    |
| ----------------- | ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| **Enaria EA**     | `/Users/memeonlymellc/enaria/enaria-horizon5-portfolio` | Fork of Horizon EA                                                                                                          |
| **Enaria API**    | `/Users/memeonlymellc/enaria/enaria-horizon5-mt-api`    | Fork of Horizon API                                                                                                         |
| **Enaria Agents** | `/Users/memeonlymellc/enaria/enaria-agents`             | Autonomous agent system that consumes the Enaria API (`tools/trading/`) to read data and push events for the EA to process. |

## Sync workflow

- Use `~/.claude/hooks/cross-check.sh <source> <target>` to diff two projects and identify drift (e.g., `~/.claude/hooks/cross-check.sh /Users/memeonlymellc/horizon5-portfolio /Users/memeonlymellc/enaria/enaria-horizon5-portfolio`).
- After working on any core project, check whether the Enaria forks or dependent projects need the same changes and notify the user.
