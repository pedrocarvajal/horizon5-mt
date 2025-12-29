# How to Read Log Files

Log files in Horizon5 can be very large. Follow these guidelines to efficiently analyze them.

## General Approach

1. **Never read the entire file** - Use `Grep` to search for specific patterns first
2. **Identify the context** - Determine which strategy or component you're investigating
3. **Filter by prefix** - Each component has a unique prefix in brackets

## Log Format

```
[LEVEL] Prefix: message
```

Levels: `DEBUG`, `INFO`, `WARNING`, `ERROR`

## Searching by Strategy

Filter logs by strategy prefix:

```
Grep pattern="Statistics\[StrategyName\]"
```

## Backtesting Performance Metrics

Statistics snapshots are printed by `SEStatistics.mqh` and contain:

| Metric                | Description                               |
| --------------------- | ----------------------------------------- |
| Nav                   | Net Asset Value (current portfolio value) |
| Performance           | Cumulative profit/loss in dollars         |
| Winning/Losing orders | Count and total performance               |
| Max loss              | Largest single losing trade               |
| Drawdown max          | Maximum drawdown (dollars and %)          |
| Risk/Reward ratio     | Average win / max loss                    |
| Sharpe ratio          | Risk-adjusted return measure              |
| Win rate              | Percentage of winning trades              |
| Recovery factor       | Total profit / max drawdown               |
| CAGR                  | Compound Annual Growth Rate               |
| Quality               | Optimization score (0-1)                  |
| Max exposure          | Peak position size (lots and %)           |

## Finding Snapshots

Snapshots are marked with separators:

```
Grep pattern="Snapshot:"
```

## Quality Analysis

Search for quality-related messages:

```
Grep pattern="Quality"
Grep pattern="Stop out detected"
```

## Order Events

Track order lifecycle:

```
Grep pattern="ORDER_STATUS"
Grep pattern="OnOpenOrder\|OnCloseOrder"
```
