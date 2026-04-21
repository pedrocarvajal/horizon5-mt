# Adding an Asset

An asset is an `SEAsset` subclass that owns one broker symbol and hosts one or more strategies for it.

## 1. Create the asset file

```
assets/<AssetClass>/<Instrument>.mqh
```

## 2. Define the class

Extend `SEAsset`, set the name and broker symbol, then call `Setup()`:

```mql5
#include "../Asset.mqh"

input group "[<Instrument>] Strategies >";
input bool <Instrument>ExampleEnabled = false; // [1] > Enable Example strategy

class <Instrument>Asset:
public SEAsset {
public:
    <Instrument>Asset() {
        SetName("<instrument-lower>");
        SetSymbol("<SYMBOL>");
        Setup();
    }

    void Setup() {
        if (<Instrument>ExampleEnabled) {
            // instantiate and AddStrategy(...)
        }
    }
};
```

- `SetName()` — lowercase identifier used in logs and file paths.
- `SetSymbol()` — must match the broker's symbol string exactly.
- `Setup()` — called from the constructor; it instantiates strategies based on input toggles.
- Per-asset gateway routing (`SEGateway`) is instantiated automatically by `SEAsset`. You don't need to register it.

## 3. Register it in `configs/Assets.mqh`

Three additions, mirroring the existing pattern:

```mql5
// a) Include the asset file:
#include "../assets/<AssetClass>/<Instrument>.mqh"

// b) Instantiate it:
SEAsset *myAsset = new <Instrument>Asset();

// c) Append it to the assets[] array:
SEAsset *assets[] = {
    /* existing assets, */
    myAsset
};
```

## 4. Compile

Compile `Horizon.mq5`. The new asset appears in the EA inputs panel, grouped under its strategies. An asset is considered enabled when at least one of its strategies is toggled on; otherwise it is silently skipped at init.

## Capital allocation

Capital is divided equally among enabled assets, then equally among each asset's active strategies. See [Multi-Asset Portfolios](multi-asset.md) for the exact formulas and passive-strategy behavior.
