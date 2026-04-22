# Changelog

All notable changes to this project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
