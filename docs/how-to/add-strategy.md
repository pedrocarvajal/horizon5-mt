# Adding a Strategy

A strategy is an `SEStrategy` subclass registered into an asset. The framework handles lifecycle dispatch, order management, risk sizing, persistence, and reporting — your class only owns the trading logic.

## 1. Create the strategy file

Place it at:

```
strategies/<AssetClass>/<Instrument>/<Name>/<Name>.mqh
```

## 2. Define the class

Extend `SEStrategy` and set the required properties in the constructor:

```mql5
#include "../../../Strategy.mqh"

class MyStrategy:
public SEStrategy {
public:
    MyStrategy() {
        SetName("MyStrategy");
        SetPrefix("MYS");
        SetMaxLotsByOrder(10.0);
    }

    int OnInit() override {
        return SEStrategy::OnInit();
    }

    void OnStartHour() override {
        SEStrategy::OnStartHour();
        // Your logic here.
    }
};
```

- **Name** — descriptive, used in logs, file paths, and reporting.
- **Prefix** — 3-letter uppercase identifier. It is part of the magic-number seed and must be unique across the entire portfolio.
- **MaxLotsByOrder** — upper cap applied after position-sizing.

## 3. Implement trading logic

Override the lifecycle hooks you need. Typical pattern:

- Evaluate signals inside `OnStartHour()` (or another bar-level hook) after calling the parent.
- Compute lot size via `GetLotSizeByStopLoss(stopLossDistance)`.
- Normalize and validate with `NormalizeLotSize()`, `FixMarketPrice()`, `CheckStopDistance()`.
- Submit orders through the inherited `orderBook`.

See [Position Sizing](position-sizing.md) and [Risk Management](risk-management.md) for the math and guardrails.

## 4. Register in the asset file

Open the target asset file (`assets/<AssetClass>/<Instrument>.mqh`) and add:

```mql5
// a) Include the strategy header:
#include "../../strategies/<AssetClass>/<Instrument>/MyStrategy/MyStrategy.mqh"

// b) Add an input toggle in the strategy toggles group:
input bool <Instrument>MyStrategyEnabled = false; // [N] > Enable MyStrategy

// c) Inside Setup(), conditionally instantiate and register:
if (<Instrument>MyStrategyEnabled) {
    MyStrategy *myStrategy = new MyStrategy();
    AddStrategy(myStrategy);
}
```

`AddStrategy()` wires the strategy into the asset: it sets the symbol, derives the deterministic magic number, and enrolls it in event dispatch.

## 5. Compile and test

Compile `Horizon.mq5`. If the toggle is on, the strategy participates in the portfolio, receives a share of the asset's allocated balance, and runs through the normal lifecycle. Always validate in the Strategy Tester before enabling in live trading.

## Rules

- Prefix **must be unique across the entire portfolio**, not just within the asset.
- Call the parent method first when overriding lifecycle hooks.
- Use `shift=1` when reading indicator values to avoid the forming bar.
- Do not perform I/O inside `OnDeinit()` — use `OnEnd()` for final exports.
