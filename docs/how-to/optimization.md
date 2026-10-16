# Strategy Optimization

Horizon5 is compatible with MT5's built-in Strategy Tester, including its genetic and slow complete optimization modes. The framework does not prescribe an optimization methodology — it exposes the hooks MT5 expects and lets you decide how to search the parameter space.

## Tester hooks

The EA implements:

- `OnTesterInit()` — forwarded to each asset and strategy for backtest-specific initialization.
- `OnTester()` — returns a quality metric aggregating per-asset quality values (geometric mean over assets, which are themselves geometric means over their strategies' quality scores). Returns `0` if any asset's quality is zero.
- `OnTesterPass()` / `OnTesterDeinit()` — present but empty; override or extend as needed for custom optimization flows.

The quality function lives in `SEStatistics` (per strategy) and is aggregated up through `SEAsset::CalculateQualityProduct()`. This is what MT5 uses to rank optimization passes when you select **Custom max** as the optimization criterion.

## Backtest reporting

Enable during tester runs via EA inputs:

- `EnableOrderHistoryReport` — per-strategy order history JSON.
- `EnableSnapshotHistoryReport` — per-strategy snapshot JSON.
- `EnableMarketHistoryReport` — per-asset market snapshot JSON.

Reports are written under `<login>\Reports\` in MT5's Common Files folder during `OnTester()` via each asset's `ExportOrderHistory()`, `ExportStrategySnapshots()`, and `ExportMarketSnapshots()` calls.

## Parameter surface

Most tunable knobs live in the strategy class (indicators, thresholds) or in EA-wide risk inputs (`EquityAtRisk`, `EquityAtRiskCompounded`). For optimization, expose strategy-local knobs as `input` variables inside the asset file (alongside the enable toggle) so MT5's optimizer can iterate over them.
