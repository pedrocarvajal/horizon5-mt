# Adding an Asset

## 1. Create the asset file

Place it at `assets/<AssetClass>/<Instrument>.mqh`.

Example: `assets/Forex/EURUSD.mqh`.

## 2. Define the class

Extend `SEAsset`, set the name and broker symbol, call `Setup()`, and register strategies:

```mql5
#include "../../strategies/Generic/Gateway/Gateway.mqh"
#include "../Asset.mqh"

input group "[EURUSD] Strategies >";
input bool EURUSDExampleEnabled = false; // [1] > Enable Example strategy

class EURUSDAsset:
public SEAsset {
public:
    EURUSDAsset() {
        SetName("eurusd");
        SetSymbol("EURUSD");
        Setup();
    }

    void Setup() {
        Gateway *gateway = new Gateway();
        AddStrategy(gateway);

        if (EURUSDExampleEnabled) {
            // instantiate and AddStrategy(...)
        }
    }
};
```

Key points:

- `SetName()` -- lowercase identifier used in logs and file paths.
- `SetSymbol()` -- must match the exact broker symbol string in MetaTrader 5.
- `Setup()` -- must be called at the end of the constructor. It instantiates strategies based on the input toggles.
- The `Gateway` strategy is always added (it is passive and handles remote order management).

## 3. Register in configs/Assets.mqh

Open `configs/Assets.mqh` and make three additions:

**a) Include the asset file:**

```mql5
#include "../assets/Forex/EURUSD.mqh"
```

**b) Instantiate the asset:**

```mql5
SEAsset *eurusd = new EURUSDAsset();
```

**c) Add it to the `assets[]` array:**

```mql5
SEAsset *assets[] = {
    gold,
    bitcoin,
    sp500,
    nikkei225,
    eurusd
};
```

## 4. Compile

Compile `Horizon.mq5`. The new asset will appear in the EA inputs panel where its strategies can be enabled individually.

An asset is considered enabled when at least one of its strategies is enabled. Assets with no enabled strategies are silently skipped during initialization.
