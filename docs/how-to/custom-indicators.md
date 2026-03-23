# Creating Custom Indicators

## Two categories

### Market-data indicators (`indicators/` directory, `IN` prefix)

These functions call MT5's `CopyXxx` family (`CopyClose`, `CopyHigh`, `CopyBuffer`, etc.) to read market data directly. They accept a symbol, timeframe, period, and shift.

Examples:

- `INRollingReturn.mqh` -- `RollingReturn(symbol, timeframe, period, shift)` calculates the percentage return over `period` bars.
- `INHighest.mqh` -- `Highest(symbol, timeframe, priceType, period, shift)` returns the highest value in a lookback window.
- `INDrawdownFromPeak.mqh` -- drawdown from the rolling high.
- `INVolatility.mqh` -- rolling volatility measure.

Use these when you need raw price or indicator data from a specific symbol and timeframe.

### In-memory helpers (`helpers/` subdirectory, `H` prefix)

These functions operate on arrays or values already in memory. They do not call `CopyXxx` and have no market data dependency.

Examples:

- `HNormalizeLotSize.mqh` -- rounds lot size to broker constraints.
- `HCheckStopDistance.mqh` -- validates order price against broker stop level.
- `HCrossedAbove.mqh` -- detects crossover between two indicator buffers.
- `HIsRising.mqh` -- checks if a series of values is trending upward.
- `HGetIndicatorValue.mqh` -- wraps `CopyBuffer` for reading custom indicator handles.

## Using custom MT5 indicators

### Creating a handle

Call `iCustom()` in `OnInit()` to create an indicator handle:

```mql5
int handleSma = iMA(symbol, PERIOD_H1, 44, 0, MODE_SMA, PRICE_CLOSE);
```

Release handles in the destructor:

```mql5
if (handleSma != INVALID_HANDLE) {
    IndicatorRelease(handleSma);
}
```

### Reading values

Use the helpers from `HGetIndicatorValue.mqh`:

```mql5
double value = GetIndicatorValue(handle, bufferIndex, shift);
```

- `handle` -- the indicator handle from `iCustom()` or a built-in function like `iMA()`.
- `bufferIndex` -- which output buffer to read (0 for most single-output indicators).
- `shift` -- number of bars back from the current bar. `0` = current (forming) bar, `1` = last closed bar.

For multiple values at once:

```mql5
double values[];
bool success = GetIndicatorValues(handle, bufferIndex, shift, count, values);
```

Returns `true` if all requested values were copied. The array is set as series (index 0 = most recent).

## Shift parameter

The `shift` parameter in all indicators follows MT5's convention:

- `shift=0` reads the current forming bar (incomplete data).
- `shift=1` reads the last fully closed bar.
- For higher timeframes, some internal helpers add `+1` to the shift parameter, so a source shift of 1 produces an effective shift of 2 in the `CopyXxx` call. This is by design, not a bug.
