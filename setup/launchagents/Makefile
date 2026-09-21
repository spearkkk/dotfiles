SHELL := /bin/sh

PLIST_SOURCE_DIR := plists
PLIST_TARGET_DIR := $(HOME)/Library/LaunchAgents
PLISTS := $(wildcard $(PLIST_SOURCE_DIR)/*.plist)

.PHONY: install bootstrap restart status teardown unload validate

validate:
	@set -eu; \
	for plist in $(PLISTS); do \
		plutil -lint "$$plist" >/dev/null; \
		printf 'ok %s\n' "$$plist"; \
	done

install: validate
	@set -eu; \
	mkdir -p "$(PLIST_TARGET_DIR)"; \
	for plist in $(PLISTS); do \
		dest="$(PLIST_TARGET_DIR)/$$(basename "$$plist")"; \
		rm -f "$$dest"; \
		cp -p "$$plist" "$$dest"; \
		printf 'install %s\n' "$$dest"; \
	done

bootstrap: install
	@fish bootstrap.fish

restart: bootstrap

status:
	@fish status.fish

teardown unload:
	@fish teardown.fish
