# The Portfolio Approach

## Hierarchical structure

Horizon5 organizes trading as a four-level hierarchy:

```
EA (Horizon.mq5)
  -> Assets (SEAsset -- one per traded instrument)
    -> Strategies (SEStrategy -- one or more per asset)
      -> Orders (EOrder -- managed by SEOrderBook per strategy)
```

The EA owns a flat array of `SEAsset` pointers, configured in `configs/Assets.mqh`. Each asset owns its strategies, and each strategy owns an order book. Events flow top-down (the EA dispatches `OnStartHour`, `OnTick`, etc. to assets, which forward to strategies) and bottom-up (trade transactions bubble from the EA to the matching asset and strategy via magic number lookup).

## Equal-weight allocation

Capital is distributed equally across all enabled assets, and then equally across all active strategies within each asset.

On initialization:

1. The EA counts enabled assets and assigns `weightPerAsset = 1.0 / enabledAssetCount`.
2. Each asset receives `balance = accountBalance * weightPerAsset`.
3. Within an asset, active (non-passive) strategies split the asset's weight and balance equally: `weightPerStrategy = assetWeight / activeStrategyCount`.

This approach avoids prediction of which strategy or asset will outperform. Every component gets the same opportunity, and the portfolio's edge comes from diversification rather than optimization-based allocation.

## Passive vs active strategies

Strategies have an `isPassive` flag. Active strategies (the default) generate signals locally and split the asset's allocation among themselves. Passive strategies exist to handle remote orders from the Gateway -- they receive the full asset weight and balance, since the remote system controls position sizing.

In the allocation logic (`Asset.mqh`), passive strategies are excluded from the active count used to compute per-strategy weight. They get assigned `weight` and `balance` equal to the entire asset allocation.

## Magic number generation

Each strategy needs a unique MT5 magic number to identify its orders in the broker's system. Horizon5 generates these deterministically using a DJB2 hash of the string `"{symbol}_{assetName}_{strategyName}"`, modulo 1 billion:

```
hash = 5381
for each character c:
    hash = ((hash << 5) + hash) + c
magic = hash % 1_000_000_000
```

This means the same strategy on the same symbol always produces the same magic number, making order recovery after restart reliable. The EA validates uniqueness of all magic numbers on startup and refuses to run if collisions are detected.

## Deterministic UUIDs

For cross-system correlation with the Horizon API, accounts, assets, and strategies receive deterministic UUIDs generated from a seed string. The `GenerateDeterministicUuid()` function takes a seed, produces a 16-byte hash through XOR mixing and multiple diffusion rounds, then formats the result as a UUID v5-style string (version nibble set to `0x5`, variant bits set to `0b10`).

Seeds are constructed from account identifiers, symbol names, and strategy names, ensuring that the same logical entity always maps to the same UUID across EA restarts and across Monitor and Gateway integrations. This eliminates the need for server-side ID assignment -- the EA and the API independently compute the same UUID for any given entity.
