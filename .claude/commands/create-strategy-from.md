---
description: "Create a new strategy from a reference file or folder"
---

# Create Strategy From Reference

Input: $ARGUMENTS (file path or folder with strategy reference - PDF, code, documentation, or trading rules)

Execute the following steps in order:

## Step 1: Gather Complete Strategy Context

Analyze the provided reference thoroughly as a quantitative trader would:

1. **Read and understand the reference material** at `$ARGUMENTS`
2. **Extract all trading logic**:
   - Entry rules (long and short conditions)
   - Exit rules (take profit, stop loss, trailing stops)
   - Position sizing methodology
   - Timeframe(s) used
   - Indicators and their parameters
   - Filters (trend, volatility, time-based)
   - Risk management rules
3. **Identify the asset class** and specific instruments
4. **Document edge cases** and special conditions
5. **Clarify any ambiguities** with the user before proceeding

Output a summary of the strategy logic to confirm understanding with the user.

## Step 2: Understand Framework Architecture

Investigate the Horizon5 framework to understand implementation patterns:

1. **Study the base class**: `/Users/memeonlymellc/horizon5-portfolio/strategies/Strategy.mqh`
2. **Analyze existing strategies** in `/Users/memeonlymellc/horizon5-portfolio/strategies/` to understand:
   - How strategies inherit from SEStrategy
   - How OnTick, OnStartMinute, OnStartHour, OnStartDay are used
   - How indicators are initialized and used
   - How orders are opened with OpenNewOrder()
   - How to get lot sizes (GetLotSizeByCapital, GetLotSizeByVolatility)
3. **Review asset management**: `/Users/memeonlymellc/horizon5-portfolio/assets/` to understand:
   - How strategies are linked to assets
   - Asset configuration patterns
4. **Check portfolio structure**: `/Users/memeonlymellc/horizon5-portfolio/portfolios/` to understand:
   - How assets are grouped
   - Weight and balance allocation
5. **Review available services**:
   - SELogger for logging
   - SEStatistics for performance tracking
   - SEDateTime for time operations
   - Available indicators in `/Users/memeonlymellc/horizon5-portfolio/indicators/`

## Step 3: Implement the Strategy

Create the strategy following clean architecture principles:

1. **Create strategy file** in appropriate location under `/Users/memeonlymellc/horizon5-portfolio/strategies/`
2. **Implementation standards**:
   - Use descriptive variable and method names
   - Follow existing code patterns and conventions
   - Implement proper initialization in OnInit()
   - Add strategic logging for debugging (entry signals, exits, state changes)
   - Handle edge cases gracefully
   - Validate inputs and indicator values
3. **Include proper logging**:
   - Log entry/exit signals with relevant data
   - Log indicator values at decision points
   - Use appropriate log levels (info, warning, error)
4. **Register strategy** in the corresponding asset file
5. **Test compilation** to ensure no syntax errors

## Step 4: Report and Await Instructions

Provide a comprehensive summary:

1. **Files created/modified** with paths
2. **Strategy overview**:
   - Name and prefix assigned
   - Entry conditions implemented
   - Exit conditions implemented
   - Timeframe and indicators used
   - Risk management approach
3. **Configuration notes**:
   - Required indicator parameters
   - Suggested optimization ranges
   - Asset/portfolio integration details
4. **Pending items** (if any):
   - Features that need clarification
   - Optional enhancements
   - Testing recommendations

Wait for user feedback on modifications or adjustments needed.
