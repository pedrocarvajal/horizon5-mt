# Naming Conventions

## Strategy Names

Strategies are named after cities, grouped by the asset class they trade.

### Gold (XAUUSD) -- Australian cities

Ballarat, Bendigo, Cairns, Darwin, Geelong, Hobart, Mackay, Tamworth, Toowoomba, Wollongong.

### Nikkei225 -- Japanese cities

Fukuoka, Kobe, Kyoto, Nagoya, Nara, Niigata, Nikko, Osaka, Sapporo, Yokohama.

### SP500 -- American cities

Austin, Charlotte, Denver, Memphis, Nashville, Phoenix, Portland, Raleigh, Tampa, Tucson.

### Rules

- Names must be easy to pronounce. Avoid obscure or hard-to-say city names.
- Each strategy has a 3-letter uppercase prefix used in logs and identifiers (e.g., DNV for Denver, SPR for Sapporo).

## File Paths

### Strategy files

```
strategies/<AssetClass>/<Instrument>/<Name>/<Name>.mqh
```

Examples:

- `strategies/Commodities/Gold/Ballarat/Ballarat.mqh`
- `strategies/Indices/Nikkei225/Osaka/Osaka.mqh`
- `strategies/Indices/SP500/Denver/Denver.mqh`

### Asset registration files

```
assets/<AssetClass>/<Instrument>.mqh
```

Examples:

- `assets/Commodities/Gold.mqh`
- `assets/Indices/Nikkei225.mqh`
- `assets/Indices/SP500.mqh`

Each asset file includes strategy headers and defines the `<Asset><Strategy>Enabled` input toggles.

## Code Prefixes

| Prefix | Location      | Purpose                                                                          |
| ------ | ------------- | -------------------------------------------------------------------------------- |
| `H`    | `helpers/`    | Pure utility functions that operate on arrays or values (no market data access). |
| `IN`   | `indicators/` | Market data functions that use `CopyXxx` to read price/indicator buffers.        |
| `SE`   | `services/`   | Core services: logging, time, lot sizing, order management, messaging.           |
| `SR`   | `services/`   | Persistence, reports, integrations, and remote order management.                 |
| `E`    | `entities/`   | Data entities such as `EOrder` and `EAccount`.                                   |
| `S`    | `structs/`    | Plain structs for data transfer (e.g., `SDateTime`, `STradingStatus`).           |
| `I`    | `interfaces/` | Interface definitions (e.g., `IStrategy`).                                       |
