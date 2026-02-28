.PHONY: all check test lint clean install install-bin install-etc install-share help

SHELL := /bin/bash
BIN_DIR := $(CURDIR)/bin
ETC_DIR := $(CURDIR)/etc
SHARE_DIR := $(CURDIR)/share
TEST_DIR := $(CURDIR)/t

SCRIPTS := $(wildcard $(BIN_DIR)/*)
TEST_FILES := $(wildcard $(TEST_DIR)/*.t)

INSTALL_PREFIX ?= $(HOME)/.local
INSTALL_BIN := $(INSTALL_PREFIX)/bin
INSTALL_ETC := $(INSTALL_PREFIX)/etc
INSTALL_SHARE := $(INSTALL_PREFIX)/share

all: check test

help:
	@echo "Available targets:"
	@echo "  make all         - Run check and test (default)"
	@echo "  make check       - Alias for lint"
	@echo "  make test        - Run all test files in t/"
	@echo "  make lint        - Lint all scripts with shellcheck"
	@echo "  make install     - Install scripts, etc, and share"
	@echo "  make install-bin - Install scripts to \$$HOME/.local/bin"
	@echo "  make install-etc - Install etc to \$$HOME/.local/etc"
	@echo "  make install-share - Install share to \$$HOME/.local/share"
	@echo "  make clean       - Remove installed files"
	@echo ""
	@echo "Variables:"
	@echo "  INSTALL_PREFIX   - Installation prefix (default: ~/.local)"

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

install: install-bin install-etc install-share
	@echo "Installation complete."

install-bin:
	@echo "Installing scripts to $(INSTALL_BIN)..."
	@mkdir -p $(INSTALL_BIN)
	@for script in $(SCRIPTS); do \
		base=$$(basename "$$script"); \
		ln -sf "$$script" "$(INSTALL_BIN)/$$base"; \
	done

install-etc:
	@echo "Installing etc to $(INSTALL_ETC)..."
	@mkdir -p $(INSTALL_ETC)
	@rsync -a --exclude='.*' $(ETC_DIR)/ $(INSTALL_ETC)/

install-share:
	@echo "Installing share to $(INSTALL_SHARE)..."
	@mkdir -p $(INSTALL_SHARE)
	@rsync -a --exclude='.*' $(SHARE_DIR)/ $(INSTALL_SHARE)/

clean:
	@echo "Cleaning up..."
	@rm -rf $(INSTALL_PREFIX)/bin/rpk $(INSTALL_PREFIX)/etc/scripts $(INSTALL_PREFIX)/share/*
