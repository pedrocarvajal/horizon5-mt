# Live Trading Setup

Live trading runs entirely inside `Horizon.mq5`. No companion MT5 service, DLL import, or WebRequest URL is required: attach the EA to a chart on a live account and it handles persistence, recovery, and reconciliation itself.

## Crash-recovery persistence

In live trading, each strategy persists its state as JSON under MT5's Common Files folder, in `<login>\Live\<symbol>\<prefix>\`:

- `orders.json` — the strategy's orders (`SRPersistenceOfOrders`).
- `statistics.json` — cumulative statistics (`SRPersistenceOfStatistics`).
- `state.json` — strategy-defined key/value state (`SRPersistenceOfState`).

Files are written through `SEDb`, a JSON document store implemented in pure MQL5. On init each strategy reloads them; if its orders cannot be restored, the EA refuses to initialize. Persistence is skipped in the Strategy Tester.

## Order reconciliation

`SRAccountAuditor` cross-checks MT5 positions, pending orders, and tracked orders on init and at the start of every hour, and logs any divergence.

## Manual-intervention pause

If a position of an asset is closed by hand from the terminal, mobile, or web, or one of its pending orders is cancelled outside the EA, that asset pauses until the start of the next day. Its pending orders are cancelled and no new entries are placed; its open positions keep their stops and continue to be managed. Other assets keep trading.
