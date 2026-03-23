# Adding a Strategy

## 1. Create the strategy file

Place the file at `strategies/<AssetClass>/<Instrument>/<Name>/<Name>.mqh`.

Example path: `strategies/Commodities/Gold/Sydney/Sydney.mqh`.

## 2. Define the class

Extend `SEStrategy` and set the required properties in the constructor:

```mql5
#include "../../../Strategy.mqh"

class Sydney:
public SEStrategy {
public:
    Sydney() {
        SetName("Sydney");
        SetPrefix("SYD");
        SetMaxLotsByOrder(10.0);
    }

    int OnInit() {
        SEStrategy::OnInit();
        return INIT_SUCCEEDED;
    }

    void OnStartHour() {
    }
};
```

- **Name** -- descriptive, used in logs and persistence.
- **Prefix** -- 3-letter uppercase abbreviation (SYD, ADL, BRN). Must be unique across the entire portfolio because it feeds into the magic number.
- **MaxLotsByOrder** -- caps the maximum lot size for any single order.

## 3. Implement trading logic

Override `OnStartHour()` (called once per hour) or other lifecycle hooks. Use `GetLotSizeByStopLoss(distance)` to calculate position size and `orderBook` to place orders.

## 4. Register the strategy in its asset file

Open `assets/<AssetClass>/<Instrument>.mqh` (e.g., `assets/Commodities/Gold.mqh`) and make three additions:

**a) Include the strategy file at the top:**

```mql5
#include "../../strategies/Commodities/Gold/Sydney/Sydney.mqh"
```

**b) Add an input toggle:**

```mql5
input bool GoldSydneyEnabled = false; // [N] > Enable Sydney strategy
```

**c) Add the instantiation block inside `Setup()`:**

```mql5
if (GoldSydneyEnabled) {
    Sydney *sydney = new Sydney();
    AddStrategy(sydney);
}
```

## 5. Compile and test

Compile `Horizon.mq5`. The compiler will catch missing includes or type errors. Run the strategy tester to validate the new strategy before deploying.

## Naming conventions

- **Gold** -- Australian city names (Sydney, Adelaide, Brisbane, Perth, etc.).
- **Nikkei225** -- Japanese city names (Kyoto, Osaka, Kobe, Nara, Sendai).
- **SP500** -- American city names (Austin, Denver, Portland, Raleigh, etc.).
- Names must be easy to pronounce; avoid obscure names.
