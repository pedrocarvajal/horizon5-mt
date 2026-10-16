# Multi-Asset Portfolios

## Capital allocation

The EA uses equal-weight allocation at two levels.

### Asset level

On startup, the EA counts assets that have at least one enabled strategy. The account balance is divided equally:

```
weightPerAsset  = 1.0 / enabledAssetCount
balancePerAsset = accountBalance * weightPerAsset
```

Assets with zero enabled strategies are skipped entirely — they neither receive capital nor appear in the event loop.

### Strategy level (within each asset)

Each asset divides its share equally among its enabled strategies:

```
balancePerStrategy = assetBalance / strategyCount
```

### Example

Account: $100,000. Two assets enabled. Asset A has three enabled strategies; asset B has one.

- Each asset gets $50,000.
- Asset A's three strategies each get $16,666.67.
- Asset B's one strategy gets $50,000.

## Enabling and disabling assets

An asset is enabled by toggling on at least one of its strategies:

```
input bool <Instrument><Strategy>Enabled = true;
```

If every toggle for an asset is `false`, the asset is skipped at init and receives no capital.

## Enabling and disabling strategies

Each strategy has its own toggle in the asset's input group. Toggles are independent; enabling or disabling one does not affect others. Disabling a strategy redistributes its allocation equally among the remaining active strategies in that asset on the next initialization.

## Adding new assets

See [Add an Asset](add-asset.md). Once registered in `configs/Assets.mqh`, the new asset participates in equal-weight allocation automatically.
