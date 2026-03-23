# Creating Your First Strategy

This guide walks through creating a new strategy from scratch. The example creates a simplified long-only strategy for the S&P 500 called "Savannah" (following the American city naming convention).

## Step 1: Create the strategy file

Create the file at `strategies/Indices/SP500/Savannah/Savannah.mqh`.

The path follows the pattern `strategies/<AssetClass>/<Instrument>/<Name>/<Name>.mqh`.

```mql5
#ifndef __STRATEGY_SAVANNAH_MQH__
#define __STRATEGY_SAVANNAH_MQH__

#include "../../../../helpers/HGetIndicatorValue.mqh"
#include "../../../../helpers/HFixMarketPrice.mqh"
#include "../../../../helpers/HCheckStopDistance.mqh"
#include "../../../../helpers/HNormalizeLotSize.mqh"

#include "../../../../services/SEDateTime/structs/SDateTime.mqh"

#include "../../../Strategy.mqh"

extern SEDateTime dtime;

class Savannah:
public SEStrategy {
private:
    int handleMovingAverage;
    int handleAtr;

public:
    Savannah() {
        SetName("Savannah");
        SetPrefix("SVN");
        SetMaxLotsByOrder(10.0);

        handleMovingAverage = INVALID_HANDLE;
        handleAtr = INVALID_HANDLE;
    }

    ~Savannah() {
        if (handleMovingAverage != INVALID_HANDLE) {
            IndicatorRelease(handleMovingAverage);
        }

        if (handleAtr != INVALID_HANDLE) {
            IndicatorRelease(handleAtr);
        }
    }

    int OnInit() {
        SEStrategy::OnInit();

        handleMovingAverage = iMA(symbol, PERIOD_H1, 50, 0, MODE_SMA, PRICE_CLOSE);
        handleAtr = iATR(symbol, PERIOD_H1, 14);

        if (handleMovingAverage == INVALID_HANDLE || handleAtr == INVALID_HANDLE) {
            logger.Error("Failed to create indicator handles");
            return INIT_FAILED;
        }

        return INIT_SUCCEEDED;
    }

    void OnStartHour() override {
        SEStrategy::OnStartHour();

        if (orderBook.HasActiveOrders()) {
            return;
        }

        if (!checkLongSignal()) {
            return;
        }

        placeBuyOrder();
    }

private:
    bool checkLongSignal() {
        double maValue = GetIndicatorValue(handleMovingAverage, 0, 1);
        double closePrice[];

        if (CopyClose(symbol, PERIOD_H1, 1, 1, closePrice) <= 0) {
            return false;
        }

        return closePrice[0] > maValue;
    }

    void placeBuyOrder() {
        double atrValue = GetIndicatorValue(handleAtr, 0, 1);

        if (atrValue == 0) {
            return;
        }

        double stopLossDistance = 1.5 * atrValue;
        double takeProfitDistance = 3.0 * atrValue;

        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double stopLossPrice = FixMarketPrice(ask - stopLossDistance, symbol);
        double takeProfitPrice = FixMarketPrice(ask + takeProfitDistance, symbol);
        double roundedStopLossDistance = ask - stopLossPrice;
        double lotSize = GetLotSizeByStopLoss(roundedStopLossDistance);

        if (lotSize <= 0) {
            return;
        }

        lotSize = NormalizeLotSize(lotSize, symbol);

        if (lotSize == 0) {
            return;
        }

        orderBook.PlaceOrder(
            ORDER_TYPE_BUY,
            ask,
            lotSize,
            false,
            takeProfitPrice,
            stopLossPrice
        );
    }
};

#endif
```

### Key points in the strategy file

- **Extend `SEStrategy`** -- this is the base class that provides `orderBook`, `logger`, `symbol`, lot sizing, state persistence, and statistics.
- **Set name and prefix in the constructor** -- `SetName("Savannah")` and `SetPrefix("SVN")`. The 3-letter prefix must be unique across all strategies in the entire portfolio.
- **Call the parent in overrides** -- always call `SEStrategy::OnInit()` at the start of `OnInit()` and `SEStrategy::OnStartHour()` at the start of `OnStartHour()`. The base class performs critical setup in these methods.
- **Use shift=1** -- when reading indicator values, use shift 1 (the previous closed bar) to avoid repainting signals on the current forming bar.
- **Guard against duplicate orders** -- use `orderBook.HasActiveOrders()`, `orderBook.HasOpenPosition()`, or `orderBook.HasPendingOrder()` before placing orders.
- **Position sizing** -- `GetLotSizeByStopLoss(stopLossDistance)` calculates the lot size based on the equity-at-risk percentage configured in the EA inputs.
- **Release indicator handles** -- always release handles in the destructor with `IndicatorRelease()`.
- **Normalize before placing** -- use `NormalizeLotSize()` and `FixMarketPrice()` to round values to broker-valid increments.

## Step 2: Register in the asset file

Open `assets/Indices/SP500.mqh` and add three things:

### 2a. Include the strategy file

Add the include at the top of the file, alongside the other strategy includes:

```mql5
#include "../../strategies/Indices/SP500/Savannah/Savannah.mqh"
```

### 2b. Add the input toggle

Add a new `input bool` in the strategy toggles section:

```mql5
input bool SP500SavannahEnabled = false; // [N] > Enable Savannah strategy
```

Replace `[N]` with the next sequential number in the list.

### 2c. Add the if-block in Setup()

Inside the `Setup()` method, add the conditional instantiation:

```mql5
if (SP500SavannahEnabled) {
    Savannah *savannah = new Savannah();
    AddStrategy(savannah);
}
```

This follows the same pattern used by every other strategy in the asset file. The `AddStrategy()` call registers the strategy with the asset, which handles initialization, tick routing, and lifecycle management.

## Step 3: Register a new asset (only if needed)

If you are adding a strategy for an instrument that does not yet have an asset file, you also need to:

1. Create a new asset file at `assets/<AssetClass>/<Instrument>.mqh` following the pattern in `assets/Commodities/Gold.mqh`.
2. Register it in `configs/Assets.mqh` by adding an include, instantiating the asset, and adding it to the `assets[]` array.

The current registered assets are Gold (XAUUSD), Bitcoin, SP500, and Nikkei225.

## Naming conventions

Strategies are named after cities, grouped by asset class:

| Asset Class | Convention        | Examples                                              |
| ----------- | ----------------- | ----------------------------------------------------- |
| Gold        | Australian cities | Ballarat, Bendigo, Cairns, Darwin, Hobart, Wollongong |
| Nikkei 225  | Japanese cities   | Fukuoka, Kobe, Kyoto, Nagoya, Osaka, Sapporo          |
| S&P 500     | American cities   | Austin, Denver, Memphis, Nashville, Portland, Tampa   |

Choose city names that are easy to pronounce. The 3-letter uppercase prefix (e.g. SVN, DNV, AUS) must be unique across the entire portfolio, not just within the asset class.

## Lifecycle overview

Once registered, the EA manages the strategy lifecycle automatically:

1. **OnInit()** -- called once at startup. Create indicator handles, restore persisted state.
2. **OnStartHour()** -- called at the start of each hour. This is where most strategies evaluate signals and place orders.
3. **OnStartDay()** -- called at the start of each trading day. Use for daily resets or recalculations.
4. **OnOpenOrder(order)** -- called when a pending order fills.
5. **OnCloseOrder(order, reason)** -- called when a position closes.
6. **OnDeinit()** -- called at shutdown. Do not perform I/O here; only clean up local resources.
