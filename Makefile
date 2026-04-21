.PHONY: all check test lint clean install install-bin install-etc install-share install-man help

-include config.mk

SHELL := /bin/bash
BIN_DIR := $(CURDIR)/bin
ETC_DIR := $(CURDIR)/etc
SHARE_DIR := $(CURDIR)/share
MAN_DIR := $(CURDIR)/man
TEST_DIR := $(CURDIR)/t

SCRIPTS := $(wildcard $(BIN_DIR)/*)
MAN_PAGES := $(wildcard $(MAN_DIR)/*.1)
TEST_FILES := $(wildcard $(TEST_DIR)/*.t)

INSTALL_PREFIX ?= $(HOME)/.local
INSTALL_BIN ?= $(INSTALL_PREFIX)/bin
INSTALL_ETC ?= $(INSTALL_PREFIX)/etc
INSTALL_SHARE ?= $(INSTALL_PREFIX)/share
INSTALL_MAN ?= $(INSTALL_PREFIX)/share/man

all: check test

help:
	@echo "Available targets:"
	@echo "  make all         - Run check and test (default)"
	@echo "  make check       - Alias for lint"
	@echo "  make test        - Run all test files in t/"
	@echo "  make lint        - Lint all scripts with shellcheck"
	@echo "  make install     - Install scripts, etc, share, and man pages"
	@echo "  make install-bin - Install scripts to \$$INSTALL_BIN"
	@echo "  make install-etc - Install etc to \$$INSTALL_ETC"
	@echo "  make install-share - Install share to \$$INSTALL_SHARE"
	@echo "  make install-man - Install man pages to \$$INSTALL_MAN"
	@echo "  make clean       - Remove installed files"
	@echo ""
	@echo "Variables:"
	@echo "  INSTALL_PREFIX   - Installation prefix (default: ~/.local)"
	@echo "  INSTALL_ETC      - Configuration directory (default: PREFIX/etc)"

check: lint

test:
	@echo "Running tests..."
	@for t in $(TEST_FILES); do \
		echo "Testing $$t"; \
		bash "$$t" || exit 1; \
	done

lint:
	@echo "Linting scripts..."
	@for script in $(SCRIPTS); do \
		if command -v shellcheck >/dev/null 2>&1; then \
			shellcheck "$$script" || true; \
		else \
			echo "shellcheck not installed, skipping $$script"; \
		fi \
	done

install: install-bin install-etc install-share install-man
	@echo "Installation complete."

install-bin:
	@echo "Installing scripts to $(INSTALL_BIN)..."
	@mkdir -p "$(DESTDIR)$(INSTALL_BIN)"
	@for script in $(SCRIPTS); do \
		base=$$(basename "$$script"); \
		ln -sf "$$script" "$(DESTDIR)$(INSTALL_BIN)/$$base"; \
	done

install-etc:
	@echo "Installing etc to $(INSTALL_ETC)..."
	@if [ -d "$(ETC_DIR)/bash_completion.d" ]; then \
		mkdir -p "$(DESTDIR)$(INSTALL_ETC)"; \
		rsync -a --exclude='.*' "$(ETC_DIR)/" "$(DESTDIR)$(INSTALL_ETC)/"; \
	else \
		echo "etc directory not found, skipping"; \
	fi

install-share:
	@echo "Installing share to $(INSTALL_SHARE)..."
	@if [ -d "$(SHARE_DIR)" ]; then \
		mkdir -p "$(DESTDIR)$(INSTALL_SHARE)"; \
		rsync -a --exclude='.*' "$(SHARE_DIR)/" "$(DESTDIR)$(INSTALL_SHARE)/"; \
	else \
		echo "share directory not found, skipping"; \
	fi

install-man:
	@echo "Installing man pages to $(INSTALL_MAN)..."
	@if [ -n "$(MAN_PAGES)" ]; then \
		for page in $(MAN_PAGES); do \
			section=$$(basename "$$page" | sed 's/.*\.//'); \
			dest="$(DESTDIR)$(INSTALL_MAN)/man$$section"; \
			mkdir -p "$$dest"; \
			cp "$$page" "$$dest/"; \
		done; \
	else \
		echo "no man pages found, skipping"; \
	fi

clean:
	@echo "Cleaning up..."
	@rm -rf $(INSTALL_PREFIX)/bin/rpk $(INSTALL_PREFIX)/etc/scripts $(INSTALL_PREFIX)/share/*
