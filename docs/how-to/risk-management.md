# Risk Management

## Equity at risk

Two EA inputs control the risk model:

| Input                    | Effect                                                                                         |
| ------------------------ | ---------------------------------------------------------------------------------------------- |
| `EquityAtRisk`           | Percentage of capital risked per trade (default `1` → 1%)                                      |
| `EquityAtRiskCompounded` | When `true`, risk is calculated on the strategy's current NAV instead of its allocated balance |

## Lot size formula

`SELotSize::CalculateByStopLoss()` computes:

```
dollarValuePerPoint = tickValue / tickSize
riskAmount          = equityAtRisk * nav
lotSize             = riskAmount / (stopLossDistance * dollarValuePerPoint)
```

Where:

- `tickValue`, `tickSize` come from `SymbolInfoDouble`.
- `stopLossDistance` is the absolute price distance from entry to stop.
- `nav` is either the allocated balance (non-compounded) or the strategy's current NAV (compounded).

## Volume cap

Each strategy declares a `maxLotsByOrder` in its constructor via `SetMaxLotsByOrder(...)`. After the formula runs, the result is clamped to that value to prevent outsized positions.

## Volume normalization

`NormalizeLotSize()` enforces broker constraints in order:

1. Round down to `SYMBOL_VOLUME_STEP`.
2. Return `0` (skip trade) if the result is below `SYMBOL_VOLUME_MIN`.
3. Cap at `SYMBOL_VOLUME_MAX`.

## Stop-distance validation

`CheckStopDistance()` verifies the stop/limit price respects `SYMBOL_TRADE_STOPS_LEVEL`. If the target price is too close to the current market, the order is rejected before it reaches the broker.

## Trading pause

Each asset pauses on its own, until the start of the next day, when:

- **Manual close** — a human closed one of its positions on the terminal/mobile/web.
- **Manual cancel** — one of its pending orders was cancelled outside the EA.

While an asset is paused, its pending orders are cancelled and its strategies place no new entries; its open positions keep being managed. Other assets are not affected.
