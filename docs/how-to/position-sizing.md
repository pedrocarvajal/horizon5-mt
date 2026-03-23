# Position Sizing

## SELotSize service

Each strategy owns an `SELotSize` instance, initialized with the strategy's symbol. The primary method is:

```
double GetLotSizeByStopLoss(double stopLossDistance)
```

Return values:

- **Positive value** -- the calculated lot size (before normalization).
- **-1** -- the strategy has no allocated balance (deactivated).
- **0** -- invalid inputs (zero or negative NAV, stop-loss distance, or tick data).

After this call, the strategy should pass the result through `NormalizeLotSize()` to enforce broker volume constraints before placing the order.

## Balance flow

Capital flows through three levels:

1. **EA level** -- `account.GetBalance()` reads the MT5 account balance at startup.
2. **Asset level** -- the EA divides the total balance equally among enabled assets: `balance * (1 / enabledAssetCount)`.
3. **Strategy level** -- each asset divides its allocation equally among active (non-passive) strategies: `assetBalance / activeStrategyCount`. Passive strategies (like Gateway) receive the full asset balance since they do not trade independently.

## Compounding mode

Controlled by the `EquityAtRiskCompounded` input:

- **Off** -- `GetLotSizeByStopLoss` uses the static balance assigned at startup. Position sizes remain constant regardless of P&L.
- **On** -- uses `statistics.GetNav()`, which tracks realized gains and losses. Position sizes increase after wins and decrease after losses, producing a geometric growth curve.

## Practical example

Given:

- Strategy balance: $10,000
- EquityAtRisk: 1%
- Stop-loss distance: 50 points
- Dollar value per point: $10

```
riskAmount = 0.01 * 10000 = $100
lotSize    = 100 / (50 * 10) = 0.20 lots
```

If `maxLotsByOrder` is 0.10, the result is capped to 0.10. Then `NormalizeLotSize` rounds to the broker's volume step.
