# The Portfolio Approach

## Hierarchical model

Horizon5 treats trading as a four-level hierarchy:

```
EA (Horizon.mq5)
  └── Assets (SEAsset, one per instrument)
       └── Strategies (SEStrategy, 1..N per asset)
            └── Orders (EOrder, managed by SEOrderBook per strategy)
```

The EA owns a flat array of `SEAsset` pointers, built in `configs/Assets.mqh`. Each asset owns its strategies; each strategy owns an order book; each order book owns its orders. Events flow top-down (`OnTimer`, primed-bar hooks, ticks); trade transactions flow bottom-up (the EA walks assets and delegates by magic number).

## Equal-weight allocation

Capital is divided equally at every level — no prediction about which asset or strategy will perform best.

On initialization:

1. The EA counts enabled assets and computes `weightPerAsset = 1.0 / enabledAssetCount`.
2. Each asset receives `balance = accountBalance * weightPerAsset`.
3. Within an asset, enabled strategies split the asset's balance equally: `balancePerStrategy = assetBalance / strategyCount`.

Diversification across uncorrelated strategies, not allocation optimization, is the intended source of edge.

## Magic-number generation

Each strategy needs a unique MT5 magic number. Horizon5 derives it deterministically from the string `"{symbol}_{assetName}_{strategyName}"` via DJB2 modulo 1 billion:

```
hash = 5381
for each character c:
    hash = ((hash << 5) + hash) + c
magic = hash % 1_000_000_000
```

The same strategy on the same symbol always yields the same magic. Order recovery after restart is reliable as a consequence. The EA validates global uniqueness at init and refuses to run on collision.
