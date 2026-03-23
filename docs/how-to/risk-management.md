# Configuring Risk Management

## Equity at risk

The `EquityAtRisk` input (default: `1`) sets the percentage of capital risked per trade. A value of `1` means 1% of the strategy's allocated balance (or NAV, if compounding is on).

The `EquityAtRiskCompounded` input controls which balance figure is used:

- **Off (default)** -- uses the static balance allocated at startup.
- **On** -- uses the strategy's current NAV (Net Asset Value), which accounts for realized P&L. As the strategy profits, position sizes grow; as it loses, they shrink.

## Lot size calculation

The formula in `SELotSize.CalculateByStopLoss()`:

```
dollarValuePerPoint = tickValue / tickSize
riskAmount          = equityAtRisk * nav
lotSize             = riskAmount / (stopLossDistance * dollarValuePerPoint)
```

Where:

- `tickValue` and `tickSize` come from `SymbolInfoDouble`.
- `stopLossDistance` is the absolute price distance from entry to stop-loss.
- `nav` is either the static balance or the compounded NAV.

## MaxLotsByOrder cap

Each strategy sets a `maxLotsByOrder` value in its constructor (e.g., `SetMaxLotsByOrder(10.0)`). After the lot size formula runs, the result is capped to this maximum. This prevents outsized positions even if the risk calculation produces a large number.

## NormalizeLotSize

After calculation and capping, `NormalizeLotSize()` enforces broker constraints:

1. Rounds down to the nearest `SYMBOL_VOLUME_STEP`.
2. Returns `0` if the result is below `SYMBOL_VOLUME_MIN` (trade is skipped).
3. Caps at `SYMBOL_VOLUME_MAX`.

## CheckStopDistance validation

Before placing a pending order, `CheckStopDistance()` verifies that the stop/limit price respects the broker's `SYMBOL_TRADE_STOPS_LEVEL`. If the price is too close to the current market, the order is rejected to avoid broker errors.
