.ONESHELL:

DEPLOY_TARGET := /Volumes/[C] Windows 11/Users/memeonlymellc/AppData/Roaming/MetaQuotes/Terminal/D0E8209F77C8CF37AD8BF550E51FF075/MQL5/Experts/horizon2

format:
	bash scripts/cleanup_macos_files.sh
	bash scripts/uncrustify-wrapper.sh $$(find . -type f \( -name '*.mqh' -o -name '*.mq5' \) ! -name '._*')

deploy:
	@if [ ! -d "$(DEPLOY_TARGET)" ]; then \
		echo "Error: Destination folder does not exist"; \
		exit 1; \
	fi
	rm -rf "$(DEPLOY_TARGET)"/*
	cp -R ./* "$(DEPLOY_TARGET)/"
	@echo "Deployed successfully to $(DEPLOY_TARGET)"
