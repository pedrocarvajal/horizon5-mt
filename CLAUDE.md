# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

Horizon5 is a portfolio-based algorithmic trading framework for MetaTrader 5, built in MQL5. Multiple trading strategies run simultaneously across multiple assets with intelligent order management, risk controls, and performance statistics.

## Context-First Development

Before implementing, modifying, or creating any code, you MUST gather complete context of the existing architecture:

- **Understand the class hierarchy flow**: Trace the inheritance chain and dependencies to understand available methods, properties, and helpers.
- **Check existing utilities and helpers**: Search for existing implementations before creating new functionality.
- **Avoid duplication**: Never recreate functionality that already exists. Use existing methods, helpers, and patterns.
- **Follow established patterns**: New code must align with the architectural conventions already present in the codebase.

## Architecture

### Class Hierarchy

```text
IStrategy (interface)
    └── SEStrategy (abstract base - 397 lines)
            └── [Your Strategy] (e.g., Durban, Johannesburg)

IAsset (interface)
    └── SEAsset (abstract base - 259 lines)
            └── [Your Asset] (e.g., GoldAsset)
```

### Project Structure

```text
horizon5-portfolio/
├── Horizon.mq5                 # Main Expert Advisor entry point
├── adapters/                   # External API wrappers
│   └── ATrade.mqh              # Trading operations adapter
├── assets/                     # Asset implementations
│   ├── Asset.mqh               # SEAsset base class
│   └── Commodities/
│       └── Gold.mqh            # GoldAsset implementation
├── configs/
│   └── Assets.mqh              # Asset array configuration
├── constants/
│   └── Constants.mqh           # Global macros and constants
├── entities/
│   └── EOrder.mqh              # Order entity with state machine
├── enums/
│   ├── EOrderStatuses.mqh      # PENDING, OPEN, CLOSING, CLOSED, CANCELLED
│   ├── ETradingModes.mqh       # BOTH, BUY_ONLY, SELL_ONLY
│   └── EOptimizationResultFormula.mqh
├── helpers/
│   ├── HCalculateMetricQuality.mqh
│   ├── HCalculateSharpeRatio.mqh
│   ├── HCalculateRSquared.mqh
│   ├── HCalculateCAGR.mqh
│   ├── HCalculateStability.mqh
│   ├── HDrawHorizontalLine.mqh
│   ├── HDrawVerticalLine.mqh
│   ├── HDrawRectangle.mqh
│   ├── HGetMarginPerLot.mqh
│   ├── HGetPipSize.mqh
│   ├── HGetPipValue.mqh
│   ├── HIsLiveTrading.mqh
│   ├── HIsMarketClosed.mqh
│   └── HStringToNumber.mqh
├── interfaces/
│   ├── IAsset.mqh              # Asset interface contract
│   └── IStrategy.mqh           # Strategy interface contract
├── services/
│   ├── SEDateTime/             # Time utilities
│   ├── SELogger/               # Logging with prefixes
│   ├── SELotSize/              # Position sizing calculations
│   ├── SEOrderPersistence/     # JSON order recovery
│   ├── SEReportOfOrderHistory/ # Order history export
│   ├── SERates/                # Price history retrieval
│   └── SEStatistics/           # Performance metrics
├── strategies/
│   ├── Strategy.mqh            # SEStrategy base class
│   ├── Durban/                 # Pivot reversal strategy
│   └── Johannesburg/           # Daily momentum strategy
├── structs/
│   ├── SMarketStatus.mqh
│   ├── SQualityThresholds.mqh
│   ├── SSOrderHistory.mqh
│   ├── SSQualityResult.mqh
│   └── SSStatisticsSnapshot.mqh
└── libraries/
    └── JAson.mqh               # JSON parsing library
```

## Creating Strategies

### Strategy Base Class (SEStrategy)

All strategies extend `SEStrategy` and implement lifecycle methods:

**Key Properties Available:**

- `symbol` - Trading symbol (e.g., "XAUUSD")
- `name` - Strategy name
- `prefix` - Short identifier for orders (e.g., "DRB")
- `magicNumber` - Unique order identifier
- `nav` - Net asset value (balance allocated to strategy)
- `weight` - Portfolio weight percentage
- `tradingMode` - BOTH, BUY_ONLY, or SELL_ONLY

**Key Services Available:**

- `lotSizeService` - SELotSize instance for position sizing
- `statistics` - SEStatistics instance for performance tracking
- `logger` - SELogger instance for logging

**Order Management Methods:**

- `OpenNewOrder(side, lotSize, stopLoss, takeProfit, signalPrice)` - Create and queue order
- `GetAllOrders()` - Get all orders array
- `GetOpenOrders()` - Get orders with OPEN status
- `GetPendingOrders()` - Get orders with PENDING status
- `GetClosedOrders()` - Get orders with CLOSED status
- `GetOrdersBySide(side)` - Filter by BUY/SELL
- `GetOrderById(id)` - Find specific order

**Lifecycle Methods to Override:**

```mql5
void OnStartMinute() override {}  // Every minute
void OnStartHour() override {}    // Every hour
void OnStartDay() override {}     // Every day
void OnStartWeek() override {}    // Monday start
void OnEndWeek() override {}      // Friday close
void OnStartMonth() override {}   // Month start
void OnTick() override {}         // Every tick
void OnOpenOrder(EOrder &order) override {}   // Order filled
void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason) override {}
```

### Strategy Example Pattern

```mql5
#include "../strategies/Strategy.mqh"

input group "[Asset] StrategyName"
input bool AssetStrategyEnabled = false;
input double AssetStrategyMinProfitPips = 30;

class StrategyName : public SEStrategy {
private:
    double minimumProfitInPips;

public:
    StrategyName(string symbolParam, JSON::Object *params)
        : SEStrategy("StrategyName", symbolParam, "SN") {
        minimumProfitInPips = params.getDouble("minProfitTargetInPips");
    }

    void OnStartHour() override {
        if (GetOpenOrders().Total() > 0) return;
        if (!HasValidSignal()) return;

        double lotSize = lotSizeService.CalculateByCapital(nav, symbol);
        double stopLoss = CalculateStopLoss();
        double takeProfit = CalculateTakeProfit();

        OpenNewOrder(ORDER_TYPE_BUY, lotSize, stopLoss, takeProfit);
    }
};
```

## Creating Assets

### Asset Base Class (SEAsset)

Assets extend `SEAsset` and manage a collection of strategies:

**Key Methods:**

- `Setup()` - Configure and instantiate strategies
- `GetStrategies()` - Access strategy array
- `CalculateQualityProduct()` - Geometric mean of strategy qualities

### Asset Example Pattern

```mql5
#include "../assets/Asset.mqh"
#include "../strategies/MyStrategy/MyStrategy.mqh"

input group "[Asset] Global"
input bool AssetEnabled = true;

class MyAsset : public SEAsset {
public:
    MyAsset() : SEAsset("MyAsset", "SYMBOL") {}

    void Setup() override {
        if (AssetStrategyEnabled) {
            JSON::Object *params = new JSON::Object();
            params.put("minProfitTargetInPips", AssetMinProfitPips);
            AddStrategy(new MyStrategy(symbol, params));
            delete params;
        }
    }
};
```

## Order Entity (EOrder)

**State Machine:**

```text
PENDING → OPEN → CLOSING → CLOSED
           ↘ CANCELLED
```

**Key Properties:**

- `id` - Unique identifier
- `source` - Strategy prefix
- `symbol`, `magicNumber`
- `signalPrice`, `openPrice`, `closePrice`
- `mainStopLossAtPrice`, `mainTakeProfitAtPrice`
- `status` - ENUM_ORDER_STATUSES
- `side` - ORDER_TYPE_BUY or ORDER_TYPE_SELL

**Retry Logic:** Orders retry up to 3 times with backoff when market is closed.

## Available Helpers

| Helper                     | Purpose                                          |
| -------------------------- | ------------------------------------------------ |
| `HGetPipSize(symbol)`      | Returns pip size accounting for 3/5 digit quotes |
| `HGetPipValue(symbol)`     | Dollar value per pip                             |
| `HGetMarginPerLot(symbol)` | Required margin for 1 lot                        |
| `HStringToNumber(string)`  | Hash string to ulong (magic numbers)             |
| `HIsMarketClosed(symbol)`  | Returns SMarketStatus struct                     |
| `HIsLiveTrading()`         | True if live, false if testing                   |
| `HCalculateSharpeRatio()`  | Annualized Sharpe ratio                          |
| `HCalculateRSquared()`     | Linear regression R²                             |
| `HCalculateCAGR()`         | Compound annual growth rate                      |
| `HCalculateStability()`    | Return consistency measure                       |
| `HDrawHorizontalLine()`    | Chart visualization                              |
| `HDrawVerticalLine()`      | Chart visualization                              |
| `HDrawRectangle()`         | Chart visualization                              |

## Available Services

| Service                  | Purpose                                               |
| ------------------------ | ----------------------------------------------------- |
| `SELotSize`              | `CalculateByCapital()`, `CalculateByVolatility()`     |
| `SEStatistics`           | Performance tracking, quality metrics, snapshots      |
| `SEDateTime`             | `Now()`, `Today()`, `Yesterday()`, `PreviousFriday()` |
| `SELogger`               | `debug()`, `info()`, `warning()`, `error()`           |
| `SEOrderPersistence`     | JSON-based order recovery for live trading            |
| `SEReportOfOrderHistory` | Export complete order history                         |
| `SERates`                | Price history retrieval                               |

## Interfaces

### IStrategy

```mql5
int OnInit();
void OnTick();
void OnStartMinute();
void OnStartHour();
void OnStartDay();
void OnStartWeek();
void OnStartMonth();
void OnEndWeek();
void OnOpenOrder(EOrder &order);
void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason);
void OnDeinit();
void SetAsset(string name, string symbolParam);
void SetWeight(double value);
void SetMagicNumber(ulong value);
string GetPrefix();
ulong GetMagicNumber();
```

### IAsset

```mql5
int OnInit();
void OnTick();
void OnStartMinute();
void OnStartHour();
void OnStartDay();
void OnStartWeek();
void OnStartMonth();
void OnEndWeek();
void OnOpenOrder(string strategyPrefix, EOrder &order);
void OnCloseOrder(string strategyPrefix, EOrder &order, ENUM_DEAL_REASON reason);
void OnDeinit();
void SetSymbol(string value);
void SetName(string value);
void SetBalance(double value);
int GetStrategyCount();
double CalculateQualityProduct();
```

## Trading Adapter (ATrade)

Static methods for broker communication:

```mql5
ATrade::Open(symbol, side, lotSize, stopLoss, takeProfit, magic, comment)
ATrade::Close(symbol, positionId, lotSize)
ATrade::ModifyStopLoss(symbol, positionId, stopLoss)
ATrade::ModifyTakeProfit(symbol, positionId, takeProfit)
ATrade::GetDealByOrderId(orderId)
ATrade::GetPositionIdByDealId(dealId)
```

## Coding Conventions

- **Naming**: Prefixes indicate type: `SE` (Service), `E` (Entity), `H` (Helper), `I` (Interface), `S` (Struct)
- **Strategy Prefix**: 3 uppercase letters (e.g., "DRB", "JHB")
- **Input Groups**: Use `input group "[Asset] StrategyName"` format
- **JSON Parameters**: Pass strategy config via JSON::Object in asset Setup()
- **Magic Numbers**: Generated from symbol + asset name + strategy name hash
- **Order Cleanup**: Closed orders cleaned daily via `CleanupClosedOrders()`

## Event Flow

```text
Horizon.mq5 OnTimer() (1 second)
    │
    ├── Weekly boundaries → OnStartWeek() / OnEndWeek()
    ├── Daily change → CleanupClosedOrders() + OnStartDay()
    ├── Hourly change → OnStartHour()
    ├── Monthly change → OnStartMonth()
    ├── Minute change → OnStartMinute()
    └── Every tick → OnTick() + ProcessOrders()
```

## Risk Management

- **Equity at Risk**: Configurable percentage (default 10%)
- **Position Sizing**: Capital-based or volatility-based (ATR)
- **Stop-Out Detection**: Thresholds at 20% and 50% loss
- **Exposure Tracking**: Maximum lots and percentage monitored
