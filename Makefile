.PHONY: format sync-public version-upgrade-expert version-upgrade-gateway version-upgrade-monitor version-upgrade-persistence version-upgrade-all

KIND ?= counter

format:
	./scripts/make/run-format.sh

sync-public:
	./scripts/make/run-sync-public.sh

version-upgrade-expert:
	./scripts/make/run-version-upgrade.sh expert $(KIND)

version-upgrade-gateway:
	./scripts/make/run-version-upgrade.sh gateway $(KIND)

version-upgrade-monitor:
	./scripts/make/run-version-upgrade.sh monitor $(KIND)

version-upgrade-persistence:
	./scripts/make/run-version-upgrade.sh persistence $(KIND)

version-upgrade-all:
	./scripts/make/run-version-upgrade.sh all $(KIND)
