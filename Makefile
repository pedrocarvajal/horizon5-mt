.PHONY: format deploy sync-public

format:
	./scripts/make/run-format.sh

deploy:
	./scripts/make/run-deploy.sh

sync-public:
	./scripts/make/run-sync-public.sh
