# Horizon Portfolio Framework

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Creating Assets](#creating-assets)
4. [Creating Strategies](#creating-strategies)
5. [Reporting System](#reporting-system)
6. [Tips for Large Portfolios](#tips-for-large-portfolios)
7. [Viewing Backtest Reports](#viewing-backtest-reports)

---

## Overview

Horizon is an algorithmic trading framework for MetaTrader 5 that enables multi-asset portfolio management with a single broker connection. The framework provides:

- **Multi-asset support**: Trade multiple symbols (XAUUSD, EURUSD, etc.) simultaneously
- **Strategy modularity**: Each asset can have multiple independent strategies
- **Unified order management**: Centralized order tracking, persistence, and lifecycle management
- **Built-in statistics**: Automatic calculation of performance metrics (Sharpe ratio, drawdown, R-squared, win rate)
- **Quality scoring**: Configurable optimization criteria for backtesting
- **Event-driven architecture**: Lifecycle hooks for tick, minute, hour, day, week, and month events

---

## Architecture

```
Horizon.mq5 (Entry Point)
    |
    +-- Assets[]
    |       |
    |       +-- XAUUSD (IAsset)
    |       |       +-- Strategy1 (IStrategy)
    |       |       +-- Strategy2 (IStrategy)
    |       |
    |       +-- EURUSD (IAsset)
    |               +-- Strategy3 (IStrategy)
    |
    +-- Orders[] (Global order tracking)
    |
    +-- Services
            +-- Statistics (Per-strategy metrics)
            +-- ReportOfOrderHistory (JSON export)
            +-- OrderPersistence (Live trading recovery)
```

### Core Components

| Component              | Location                            | Purpose                           |
| ---------------------- | ----------------------------------- | --------------------------------- |
| `IAsset`               | `interfaces/Asset.mqh`              | Base class for tradeable symbols  |
| `IStrategy`            | `interfaces/Strategy.mqh`           | Base class for trading strategies |
| `Order`                | `services/Order.mqh`                | Order lifecycle management        |
| `Statistics`           | `services/Statistics.mqh`           | Performance metrics calculation   |
| `ReportOfOrderHistory` | `services/ReportOfOrderHistory.mqh` | JSON report generation            |

### Event Flow

```
OnTimer() -> onStartDay() -> onStartHour() -> onStartMinute() -> onTick()
```

Each event propagates to all assets and their strategies sequentially.

---

## Creating Assets

Assets represent tradeable symbols. Create a new file in `assets/` directory.

### Step 1: Create the Asset File

**File:** `assets/EURUSD.mqh`

```cpp
#ifndef __ASSET_EURUSD_MQH__
#define __ASSET_EURUSD_MQH__

#include "../interfaces/Asset.mqh"
#include "../strategies/MyStrategy/MyStrategy.mqh"

class EURUSD:
public IAsset {
public:
    EURUSD() {
        SetName("eurusd");
        SetSymbol("EURUSD");
        SetupStrategies();
    }

    void SetupStrategies() {
        SetNewStrategy(new MyStrategy(symbol));
    }
};

#endif
```

### Step 2: Register in Horizon.mq5

```cpp
#include "assets/XAUUSD.mqh"
#include "assets/EURUSD.mqh"

IAsset *xauusd = new XAUUSD();
IAsset *eurusd = new EURUSD();

IAsset *assets[] = {
    xauusd,
    eurusd
};
```

---

## Creating Strategies

Strategies contain trading logic. Create a directory in `strategies/` with your strategy name.

### Step 1: Create Strategy File

**File:** `strategies/MyStrategy/MyStrategy.mqh`

```cpp
#ifndef __STRATEGY_MY_STRATEGY_MQH__
#define __STRATEGY_MY_STRATEGY_MQH__

#include "../../interfaces/Strategy.mqh"
#include "../../structs/SQualityThresholds.mqh"

input group "MyStrategy Settings";
input double my_take_profit = 500; // Take Profit (points)
input double my_stop_loss = 250;   // Stop Loss (points)

class MyStrategy:
public IStrategy {
public:
    MyStrategy(string strategy_symbol) {
        symbol = strategy_symbol;
        name = "MyStrategy";
        prefix = "MST";  // Unique 3-letter prefix
    }

private:
    int onInit() {
        IStrategy::onInit();
        setupQualityThresholds();
        return INIT_SUCCEEDED;
    }

    void onStartDay() {
        IStrategy::onStartDay();
        // Your daily trading logic here
        executeTradeLogic();
    }

    void executeTradeLogic() {
        double lot_size = getLotSize();
        if (lot_size <= 0) return;

        double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

        Order *order = openNewOrder(
            1,                  // layer
            ORDER_TYPE_BUY,     // side
            price,              // entry price
            lot_size,           // volume
            true                // is_market_order
        );

        if (order == NULL) return;

        order.take_profit = price + (my_take_profit * point);
        order.stop_loss = price - (my_stop_loss * point);

        ArrayResize(orders, ArraySize(orders) + 1);
        orders[ArraySize(orders) - 1] = order;
    }

    void setupQualityThresholds() {
        SQualityThresholds thresholds;
        thresholds.optimization_formula = OPTIMIZATION_BY_PERFORMANCE;
        thresholds.expected_total_return_pct_by_month = 0.01;
        thresholds.expected_max_drawdown_pct = 0.01;
        thresholds.min_total_return_pct = 0.0;
        thresholds.max_max_drawdown_pct = 0.30;
        thresholds.min_trades = 5;
        setQualityThresholds(thresholds);
    }
};

#endif
```

### Strategy Lifecycle Hooks

| Hook              | Trigger            | Use Case                     |
| ----------------- | ------------------ | ---------------------------- |
| `onInit()`        | EA initialization  | Setup indicators, thresholds |
| `onTick()`        | Every price tick   | Real-time signal detection   |
| `onStartMinute()` | New minute candle  | Minute-based logic           |
| `onStartHour()`   | New hour candle    | Hourly rebalancing           |
| `onStartDay()`    | New trading day    | Daily signals                |
| `onStartWeek()`   | Monday             | Weekly analysis              |
| `onStartMonth()`  | First day of month | Monthly rebalancing          |
| `onOpenOrder()`   | Order executed     | Post-trade actions           |
| `onCloseOrder()`  | Order closed       | Performance tracking         |

---

## Reporting System

The framework generates automatic reports through two services:

### Statistics Service

Tracks per-strategy metrics in real-time:

- **NAV (Net Asset Value)**: Equity curve tracking
- **Drawdown**: Maximum drawdown in dollars and percentage
- **Win Rate**: Winning trades / Total trades
- **Risk/Reward Ratio**: Average win / Maximum loss
- **R-Squared**: Equity curve linearity (0-1)
- **Sharpe Ratio**: Risk-adjusted returns
- **Recovery Factor**: Total profit / Maximum drawdown

### ReportOfOrderHistory Service

Exports all closed orders to JSON format with:

- Order ID, strategy name, magic number
- Entry/exit prices and times
- Profit in dollars
- Take profit and stop loss levels
- Close reason (TP, SL, Expert, Manual)

### Quality Scoring

The `OnTester()` function returns a quality score (0-1) based on configured thresholds:

```cpp
thresholds.optimization_formula = OPTIMIZATION_BY_PERFORMANCE;  // Or:
// OPTIMIZATION_BY_DRAWDOWN
// OPTIMIZATION_BY_RISK_REWARD
// OPTIMIZATION_BY_WIN_RATE
// OPTIMIZATION_BY_R_SQUARED
// OPTIMIZATION_BY_RECOVERY_FACTOR
```

---

## Tips for Large Portfolios

### 1. Use Unique Prefixes

Each strategy must have a unique 3-letter `prefix` for order identification:

```cpp
prefix = "DHB";  // DailyHighBreakout
prefix = "TST";  // Test
prefix = "MOM";  // Momentum
```

### 2. Organize by Asset

```
strategies/
    XAUUSD/
        Breakout/Breakout.mqh
        MeanReversion/MeanReversion.mqh
    EURUSD/
        TrendFollowing/TrendFollowing.mqh
```

### 3. Isolate Strategy Helpers

Keep strategy-specific helpers within the strategy folder:

```
strategies/MyStrategy/
    MyStrategy.mqh
    helpers/
        calculateSignal.mqh
        validateEntry.mqh
```

### 4. Risk Management

Configure equity at risk per portfolio, not per strategy:

```cpp
input double equity_at_risk = 1;  // Total lots for entire portfolio
input bool equity_at_risk_multiply_by_strategy = false;
```

### 5. Layer System

Use layers (0-5) to categorize order types:

- Layer 0: Primary entries
- Layer 1-5: Recovery or scaling positions

The framework tracks layer distribution quality automatically.

---

## Viewing Backtest Reports

### Report Location

Reports are saved to the MetaTrader 5 Files directory:

```
[MT5 Data Folder]/MQL5/Files/Reports/[SYMBOL]/[TIMESTAMP]/
```

**Full path example:**

```
C:\Users\[User]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL5\Files\Reports\XAUUSD\20241222_143052\
```

### Finding the Path

The path is logged at the end of each backtest:

```
Order history reports saved to: C:\...\Files\Reports\XAUUSD\20241222_143052
```

### Report Files

| File                | Content                             |
| ------------------- | ----------------------------------- |
| `OrdersReport.json` | All closed orders with full details |

### JSON Structure

```json
{
  "name": "Orders Report",
  "data": [
    {
      "order_id": "TST_1_abc123",
      "strategy_name": "Test",
      "strategy_prefix": "TST",
      "side": 0,
      "layer": 1,
      "open_time": 1703260800,
      "open_price": 2050.5,
      "close_time": 1703264400,
      "close_price": 2055.0,
      "profit_in_dollars": 450.0,
      "main_take_profit_at_price": 2055.0,
      "main_stop_loss_at_price": 2045.0
    }
  ]
}
```

### Accessing Reports Programmatically

```cpp
ReportOfOrderHistory *reporter = new ReportOfOrderHistory("/Reports/Custom", true);
reporter.PrintCurrentPath();  // Logs full filesystem path
reporter.ExportOrderHistoryToJsonFile();
```

---

## Source Files Reference

| Category    | Files                                                                                |
| ----------- | ------------------------------------------------------------------------------------ |
| Entry Point | `Horizon.mq5`                                                                        |
| Interfaces  | `interfaces/Asset.mqh`, `interfaces/Strategy.mqh`                                    |
| Services    | `services/Order.mqh`, `services/Statistics.mqh`, `services/ReportOfOrderHistory.mqh` |
| Assets      | `assets/XAUUSD.mqh`                                                                  |
| Strategies  | `strategies/Test/Test.mqh`                                                           |
| Enums       | `enums/EOrderStatuses.mqh`, `enums/EOptimizationResultFormula.mqh`                   |
| Structs     | `structs/SQualityThresholds.mqh`, `structs/SOrderHistory.mqh`                        |
