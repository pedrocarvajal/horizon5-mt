# Observability

Horizon5 provides observability through **local reporting**: JSON files written to MT5's Common Files folder through `SEDb`. No backend or external service is involved.

## Local outputs

The EA is fully self-contained, both in live trading and in the Strategy Tester:

- In live trading, order state, statistics, and strategy key/value state are persisted per strategy for crash recovery (`<login>\Live\<symbol>\<prefix>\{orders,statistics,state}.json`).
- Local reports are generated from `OnTester()` / on EA shutdown:
  - **Order history** — per strategy, full record of orders with entry/exit prices, P&L, timestamps, close reasons.
  - **Strategy snapshots** — periodic statistics per strategy (win rate, profit factor, drawdown, NAV).
  - **Market snapshots** — price, spread, rolling return, rolling drawdown, rolling volatility per asset.
  - **Logs** — all log entries collected during the session.

Reports land under `<login>\Reports\` (e.g. `<symbol>_<prefix>_Orders.json`) and logs under `<login>\Logs\Portfolio\<timestamp>_<seed>\Logs.json`. See [Reference > Architecture](../reference/architecture.md#files-on-disk) for the full layout.
