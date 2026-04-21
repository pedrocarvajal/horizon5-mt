# Custom Indicators and Helpers

The framework separates **market-data indicators** (functions that read bars) from **in-memory helpers** (pure utilities). Both live in their own directories with distinct prefixes.

## Market-data indicators — `indicators/` (`IN` prefix)

These call MT5's `CopyXxx` family (`CopyClose`, `CopyHigh`, `CopyBuffer`, ...) to read price or indicator buffers. They accept symbol, timeframe, period, and shift.

Representative functions:

- `INRollingReturn.mqh` — rolling percentage return over N bars.
- `INHighest.mqh` — highest value in a lookback window.
- `INDrawdownFromPeak.mqh` — drawdown from the rolling peak.
- `INVolatility.mqh` — rolling volatility.
- `INDailyPerformance.mqh` — day-level performance.
- `INFairValueGap.mqh`, `INSwingPoints.mqh` — structural indicators.
- `INGetPriceValue.mqh` — price lookup at a given shift.

Use them whenever you need raw market data tied to a specific symbol/timeframe.

## In-memory helpers — `helpers/` (`H` prefix)

These operate on values or arrays already in memory. No market data dependency.

Representative functions:

- `HNormalizeLotSize.mqh` — round lot size to broker volume step/min/max.
- `HCheckStopDistance.mqh` — validate SL/TP against `SYMBOL_TRADE_STOPS_LEVEL`.
- `HGetIndicatorValue.mqh` — wrap `CopyBuffer` for custom indicator handles.
- `HClampNumeric.mqh`, `HStringToNumber.mqh`, `HMapTimeframe.mqh` — generic utilities.
- `HGet*Uuid.mqh` — deterministic UUID construction.
- `HGetPipSize.mqh`, `HGetPipValue.mqh` — symbol-scale helpers.
- `HDrawHorizontalLine.mqh`, `HDrawVerticalLine.mqh`, `HDrawRectangle.mqh` — chart annotations.
- `HIsMarketClosed.mqh`, `HIsLiveTrading.mqh`, `HIsLiveEnvironment.mqh` — environment/status checks.

## Using built-in or custom MT5 indicators

Create the handle in `OnInit()`:

```mql5
int handle = iMA(symbol, PERIOD_H1, 50, 0, MODE_SMA, PRICE_CLOSE);
```

Release it in the destructor:

```mql5
if (handle != INVALID_HANDLE) {
    IndicatorRelease(handle);
}
```

Read values through the helper:

```mql5
double value = GetIndicatorValue(handle, bufferIndex, shift);
```

- `bufferIndex` — the indicator output buffer (0 for most single-output indicators).
- `shift` — number of bars back. `0` is the forming bar; use `1` for the last closed bar.

For multiple values at once:

```mql5
double values[];
bool ok = GetIndicatorValues(handle, bufferIndex, shift, count, values);
```

Returns `true` if the requested range was copied; the array is series-indexed (index 0 = most recent).

## Shift semantics

All indicators follow MT5's convention:

- `shift=0` — current (forming) bar, incomplete data.
- `shift=1` — last fully closed bar. Use this for non-repainting signals.
- For higher-timeframe helpers that internally add `+1` to shift, a source shift of `1` produces an effective shift of `2` in the underlying `CopyXxx` call. This is intentional.
