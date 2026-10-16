.PHONY: format sync-public compile backtest version-upgrade-expert

KIND ?= counter
MODE ?= check
TERMINAL ?=
INI ?=

format:
	./scripts/make/run-format.sh

sync-public:
	./scripts/make/run-sync-public.sh

compile:
	./scripts/make/run-compile.sh $(MODE) $(TERMINAL)

backtest:
	./scripts/make/run-backtest.sh $(INI) $(TERMINAL)

version-upgrade-expert:
	./scripts/make/run-version-upgrade.sh expert $(KIND)
