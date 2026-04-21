# Naming Conventions

## File paths

Asset and strategy files live at fixed paths so the registry, magic-number hashing, and log namespacing all stay aligned.

### Asset files

```
assets/<AssetClass>/<Instrument>.mqh
```

`<AssetClass>` is a free-form grouping label (e.g. `Commodities`, `Indices`, `Forex`) — it affects only the directory tree. `<Instrument>` is the asset name you register (matches `SetName()`'s value, PascalCase).

### Strategy files

```
strategies/<AssetClass>/<Instrument>/<Name>/<Name>.mqh
```

Each strategy gets its own folder. The folder name, the file name, and `SetName()` should all match.

## Strategy identifiers

Each strategy must declare:

- **Name** — descriptive, easy-to-pronounce label. Used in logs, file paths, and reporting.
- **Prefix** — 3-letter uppercase code. Unique **across the entire portfolio**, not just within its asset. The prefix is part of the magic-number seed, so uniqueness is a hard invariant enforced on init.

Pick names you can say out loud in a conversation or log line without ambiguity. The framework does not prescribe a naming theme — only that names and prefixes stay memorable and unique.

## Code prefixes

| Prefix | Location      | Role                                                                                |
| ------ | ------------- | ----------------------------------------------------------------------------------- |
| `H`    | `helpers/`    | Pure utility functions operating on values or arrays — no market-data access        |
| `IN`   | `indicators/` | Market-data functions that call `CopyXxx` to read bars or indicator buffers         |
| `SE`   | `services/`   | Core services (time, logging, sizing, bus, order book, statistics, gateway routing) |
| `SR`   | `services/`   | Persistence, reports, integrations, reconciliation                                  |
| `E`    | `entities/`   | Domain entities (e.g. `EOrder`, `EAccount`)                                         |
| `S`    | `structs/`    | Plain data-transfer structs (e.g. `SDateTime`, `STradingStatus`)                    |
| `I`    | `interfaces/` | Interface definitions (e.g. `IStrategy`, `IAsset`)                                  |
| `CO`   | `constants/`  | Compile-time constant groups (times, message bus channels, order limits, etc.)      |
| `A`    | `adapters/`   | Thin wrappers over MT5 subsystems (e.g. `ATrade` around `CTrade`)                   |

## Identifier policy

- **Magic numbers** — derived deterministically from `"{symbol}_{assetName}_{strategyName}"` via DJB2 hash, modulo 1 billion. Computed locally, validated for uniqueness at init.
- **UUIDs** — deterministic UUID v5-style values derived from seed strings (account, asset, strategy, order). The EA and any external backend (Monitor, Gateway) compute matching UUIDs independently — no registration handshake is needed.

See [Explanation > Portfolio Approach](../explanation/portfolio-approach.md) for the rationale.
