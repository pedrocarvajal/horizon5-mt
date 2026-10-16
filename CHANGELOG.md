# Changelog

All notable changes to this project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.420] - 2026-10-16

### Removed

- Removed dead code with no caller: the chart drawing, pip size and pip value helpers, two unused rolling indicators and their duplicate helpers, `IsHigherFor`/`IsLowerFor`, `ATrade.ModifyStopLoss`/`ModifyTakeProfit`, `EAccount.GetMarginLevel`, and seven unused log codes (the remaining codes keep their numbers).
- Removed the per-strategy weight, which was set on every strategy but never read; lot size comes from the equity-at-risk settings.
- Removed the order's commission, swap and gross-profit fields, which were written on close but never read or persisted; net profit is unchanged.

## [0.419] - 2026-10-16

### Added

- Added `make backtest`, which runs a backtest through RControl and saves its bundle in `storage/results/<timestamp>/`.
- Vendored the custom indicators the strategies load with `iCustom`; `make compile` uploads and compiles them before the EA.

### Fixed

- Retried pending-order cancellations that hit a closed session: the canceller now marks the order to cancel, as the closer already did, so the retry runs when the session opens instead of leaving the order live to fill later.

## [0.418] - 2026-10-16

### Added

- Paused an asset until the next day when one of its pending orders is cancelled outside the EA, as a manual close already did.

### Fixed

- Scoped the manual-intervention pause to the asset: closing a position by hand on one symbol no longer cancels the pending orders of every other asset and blocks their entries. Open positions keep their stops.
- Routed pause cancellations through the canceller's retry schedule, so a closed market no longer retries the cancel every second.

### Removed

- Removed the global `STradingStatus` and `ETradingPauseReason`, replaced by the per-asset `ETradingStatus`.

## [0.417] - 2026-10-16

### Added

- Added `make compile`, which packages the sources and compiles `Horizon.mq5` on an MT5 terminal through the RControl API, and the `rcontrol` skill that documents the API workflow.

### Changed

- Rewrote `services/SEDb` in pure MQL5: collections are kept in memory and flushed as compact JSON arrays to the same `Common\Files\<account>\...` paths, with the same auto-flush, `_id`, and swap-remove semantics. `Flush` writes a temporary file and moves it into place; a file that exists but cannot be read is moved aside as `.corrupt` and live `OnInit` fails instead of overwriting it; documents with NaN or infinite numbers are rejected. `SEDbCollection.Find(SEDbQuery&)` became `FindAll`, and `UpsertOne` replaces the find-then-insert-or-update pattern.
- Decoupled live initialization from MT5 services: removed the message-bus readiness check that failed `OnInit`; order persistence writes directly through `SEDb`.
- Rewrote `/compile`, `/backtest`, `/check-strategy`, `/create-strategy-from`, and the `backtest` skill to run through the RControl API instead of the mt5 CLI.
- Reduced version tooling to `make version-upgrade-expert`.
- Updated `README.md` and `docs/` to describe the standalone, DLL-free EA.

### Fixed

- Fixed the JSON library to parse exponents and every JSON escape, escape control characters and keys on output, and report non-finite numbers through `isSerializable()`.

### Removed

- Removed the Horizon Gateway and Horizon Monitor integrations, including monitor seed export, heartbeats, remote log shipping, UUID registration, and their inputs.
- Removed the MT5 service programs `HorizonGateway.mq5`, `HorizonMonitor.mq5`, and `HorizonPersistence.mq5`, with their presets and constants.
- Removed both DLLs and their C++ sources: `HorizonMessageBus` (with `SEMessageBus`) and `HorizonFileDb` (with `SEDbQuery`).
- Removed `SERequest`, `scripts/gateway-stream.sh`, the passive-strategy flag, the `TRADING_PAUSE_REASON_HORIZON_API_REQUEST`, `TRADING_PAUSE_REASON_ACCOUNT_INACTIVE`, and `TRADING_PAUSE_REASON_SERVICES_DOWN` pause reasons, the public `SEOrderBook.ModifyTakeProfit`, `SEOrderBook.ModifyStopLossAndTakeProfit`, `SEOrderBook.FindOrderIndexById`, `SEStrategy.SetPassive`, and `SEStrategy.GetStrategyUuid` methods, and the code left unused by these removals.
- Removed the tracked `.ex5` binaries (now ignored), the mt5 CLI skill, `/deploy`, `/deploy-dlls`, the CLI startup configs, and `storage/servers/`.

## [0.416] - 2026-04-22

### Added

- Rewrote `README.md` as a framework showcase with a centered logo, a "Built with Horizon5 - live portfolio case study" section featuring a portfolio-vs-benchmarks chart and a link to the public performance report, a capabilities table, an architecture diagram, an orchestration narrative, an ecosystem contact note, and a disclaimer.
- Added `docs/assets/logo.png` and `docs/assets/portfolio-returns.png` to back the README showcase visuals.
- Documented the primed-bar detection flow in `SEAsset.ProcessBarEvents()` covering M1, H1, and D1 timeframes.
- Documented the full strategy callback surface, including `OnPendingOrderPlaced`, `OnOrderUpdated`, and `OnCancelOrder`.
- Documented the new `SRAccountAuditor` and `SRReportOfMonitorSeed` services alongside the per-asset `SEGateway` routing.

### Changed

- Rewrote the `docs/` tree as official, framework-focused documentation with no strategy-specific or instrument-specific content, refreshing `docs/index.md`, `docs/getting-started/**`, `docs/how-to/**`, `docs/reference/**`, and `docs/explanation/**`.
- Hardened `scripts/make/run-sync-public.sh` to exclude `docs/portfolio/`, `docs/plans/`, `docs/requests/`, and the root private config from the public-repo sync, and to stop overwriting the public `.gitignore`.

### Removed

- Deleted the empty placeholder directories `docs/examples/` and `docs/tutorials/`.
