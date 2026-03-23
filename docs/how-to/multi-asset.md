# Multi-Asset Portfolios

## Capital allocation

The EA uses equal-weight allocation at two levels:

### Asset level

On startup, the EA counts how many assets have at least one enabled strategy. The total account balance is divided equally:

```
weightPerAsset  = 1.0 / enabledAssetCount
balancePerAsset = accountBalance * weightPerAsset
```

An asset is considered enabled when at least one of its strategies is toggled on via input parameters. Assets with no enabled strategies are skipped entirely.

### Strategy level (within each asset)

Each asset divides its allocation equally among its **active** (non-passive) strategies:

```
weightPerStrategy  = assetWeight / activeStrategyCount
balancePerStrategy = assetBalance / activeStrategyCount
```

**Passive strategies** (like Gateway) are a special case. They receive the full asset weight and balance because they do not trade autonomously -- they relay orders from the HorizonGateway service and need the full allocation context.

### Example

Account balance: $100,000. Gold and SP500 are enabled (2 assets). Gold has 3 active strategies plus Gateway.

- Each asset gets $50,000.
- Each of Gold's 3 active strategies gets $16,666.67.
- Gold's Gateway strategy gets the full $50,000.

## Enabling and disabling assets

An asset is enabled by toggling on at least one of its strategies in the EA input panel. Each strategy has a boolean input like:

```
input bool GoldBallaratEnabled = false;
```

Set it to `true` to activate. The asset file's `Setup()` method only instantiates strategies whose toggle is `true`. If all toggles for an asset remain `false`, the asset is skipped and receives no capital.

## Enabling and disabling strategies

Each strategy has its own input toggle in the asset's input group. Strategies can be enabled or disabled independently without affecting other strategies in the same asset or other assets.

When a strategy is disabled at runtime (by removing it from the next initialization), its allocated capital is redistributed equally among the remaining active strategies in that asset.

## Adding new assets to the portfolio

See [Add an Asset](add-asset.md) for the full procedure. Once registered in `configs/Assets.mqh`, the new asset participates in the equal-weight allocation automatically.
