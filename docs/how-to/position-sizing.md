# Position Sizing

## `SELotSize`

Every strategy owns an `SELotSize` instance (created automatically by the base class) initialized with its symbol. The main entry point is:

```
double GetLotSizeByStopLoss(double stopLossDistance)
```

Return semantics:

| Value           | Meaning                                                        |
| --------------- | -------------------------------------------------------------- |
| Positive number | Calculated lot size (before broker normalization)              |
| `-1`            | Strategy has no allocated balance (deactivated)                |
| `0`             | Invalid inputs (non-positive NAV, stop distance, or tick data) |

After this call, pass the result through `NormalizeLotSize(symbol)` before submitting the order.

## Balance flow

Capital propagates down three levels:

1. **EA level** — `account.GetBalance()` at startup seeds the whole portfolio.
2. **Asset level** — EA divides balance equally among enabled assets.
3. **Strategy level** — each asset divides its balance equally among active (non-passive) strategies. Passive strategies receive the full asset balance.

See [Multi-Asset Portfolios](multi-asset.md) for the formulas.

## Compounding

`EquityAtRiskCompounded` controls which balance is used:

- **Off** — the static allocation at startup. Position size is constant regardless of realized P&L.
- **On** — the strategy's current NAV (`statistics.GetNav()`), which incorporates realized gains and losses. Size grows after wins and shrinks after losses.

## Worked example

Given:

- Strategy balance: $10,000
- `EquityAtRisk`: `1` (1%)
- Stop-loss distance: 50 points
- Dollar value per point: $10

```
riskAmount = 0.01 * 10000 = 100
lotSize    = 100 / (50 * 10) = 0.20
```

If `maxLotsByOrder` is `0.10`, the result caps at `0.10`. `NormalizeLotSize` then rounds to the broker's volume step (and rejects if below minimum).
