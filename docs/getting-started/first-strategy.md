# Your First Strategy

This walkthrough adds a minimal, framework-only strategy so you can see the extension pattern end to end. The strategy itself does nothing meaningful — it is a skeleton you can fill with your own logic.

Throughout, replace the placeholders with your own values:

- `<AssetClass>` — e.g. `Commodities`, `Indices`, `Forex`. Used only for folder organization.
- `<Instrument>` — the asset name you register (e.g. `MyAsset`).
- `<SYMBOL>` — the broker symbol string for that instrument.
- `<StrategyName>` — a descriptive, easy-to-pronounce name (e.g. `Example`).
- `<PRFX>` — a 3-letter uppercase prefix, unique across the entire portfolio.

## Step 1 — Create the strategy file

Create `strategies/<AssetClass>/<Instrument>/<StrategyName>/<StrategyName>.mqh`:

```mql5
#ifndef __STRATEGY_EXAMPLE_MQH__
#define __STRATEGY_EXAMPLE_MQH__

#include "../../../Strategy.mqh"

class Example:
public SEStrategy {
public:
    Example() {
        SetName("Example");
        SetPrefix("EXM");
        SetMaxLotsByOrder(10.0);
    }

    int OnInit() override {
        return SEStrategy::OnInit();
    }

    void OnStartHour() override {
        SEStrategy::OnStartHour();

        if (orderBook.HasActiveOrders()) {
            return;
        }

        // Your signal logic goes here.
    }
};

#endif
```

Key points:

- **Extend `SEStrategy`** — you get `orderBook`, `logger`, `symbol`, sizing, statistics, persistence, and lifecycle plumbing for free.
- **Set name, prefix, and max lots in the constructor.** Prefix must be unique across the whole portfolio — it feeds into the magic-number hash.
- **Call the parent first** in overridden lifecycle methods (`OnInit`, `OnStartHour`, etc.). The base class performs required setup.
- **Use shift 1** (`CopyXxx` / `GetIndicatorValue` with `shift=1`) when reading indicators so you see the last closed bar, not the forming one.
- **Guard duplicates** with `orderBook.HasActiveOrders()` or `orderBook.HasPendingOrder()` before placing.
- **Release resources** (indicator handles, pointers) in the destructor.

## Step 2 — Register the strategy in its asset file

Open `assets/<AssetClass>/<Instrument>.mqh` and add three things, mirroring the existing pattern:

```mql5
// a) Include it:
#include "../../strategies/<AssetClass>/<Instrument>/Example/Example.mqh"

// b) Add an input toggle:
input bool <Instrument>ExampleEnabled = false; // [N] > Enable Example strategy

// c) Inside Setup(), conditionally instantiate and register it:
if (<Instrument>ExampleEnabled) {
    Example *example = new Example();
    AddStrategy(example);
}
```

`AddStrategy()` assigns the strategy its symbol, computes its deterministic magic number, and hooks it into the asset's lifecycle dispatch.

## Step 3 — (If needed) Register a new asset

If the instrument does not exist yet, create `assets/<AssetClass>/<Instrument>.mqh` extending `SEAsset`, and register it in `configs/Assets.mqh` (include, instantiate, append to the `assets[]` array). See [How-To > Add an Asset](../how-to/add-asset.md).

## Step 4 — Compile and test

Compile `Horizon.mq5`. If your toggle is on, the strategy appears in the portfolio, receives capital through equal-weight allocation, and participates in the event loop. Run it in the MT5 Strategy Tester first.

## Lifecycle hooks you can override

| Hook                                             | Fires when                                                                                        |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| `OnInit()`                                       | Once, at startup. Create indicator handles, read persisted state.                                 |
| `OnTesterInit()`                                 | Once, at tester startup.                                                                          |
| `OnTimer()`                                      | Every second (dispatch loop).                                                                     |
| `OnTick()`                                       | At the configured tick interval (default 60s).                                                    |
| `OnStartMinute() / OnStartHour() / OnStartDay()` | When a new M1/H1/D1 bar opens for the strategy's symbol.                                          |
| `OnPendingOrderPlaced(order)`                    | After a pending order is created.                                                                 |
| `OnOpenOrder(order)`                             | After a fill is confirmed by the broker.                                                          |
| `OnOrderUpdated(order)`                          | After an order's fields are modified (SL/TP changes, etc.).                                       |
| `OnCloseOrder(order, reason)`                    | After the broker confirms the exit.                                                               |
| `OnCancelOrder(order)`                           | After a pending order is cancelled/expired or a close request is rejected.                        |
| `OnEnd()` / `OnDeinit()`                         | On normal shutdown / on any deinit. Use `OnEnd` for final I/O; `OnDeinit` for local cleanup only. |
