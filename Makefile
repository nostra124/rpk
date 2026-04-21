.PHONY: all check test lint clean install install-bin install-etc install-share install-man install-doc install-skills help

-include config.mk

SHELL := /bin/bash
BIN_DIR := $(CURDIR)/bin
ETC_DIR := $(CURDIR)/etc
SHARE_DIR := $(CURDIR)/share
MAN_DIR := $(CURDIR)/man
DOC_DIR := $(CURDIR)/docs
SKILLS_DIR := $(CURDIR)/skills
TEST_DIR := $(CURDIR)/t

SCRIPTS := $(wildcard $(BIN_DIR)/*)
MAN_PAGES := $(wildcard $(MAN_DIR)/*.1)
DOC_FILES := $(wildcard $(DOC_DIR)/*.md)
TEST_FILES := $(wildcard $(TEST_DIR)/*.bats)

INSTALL_PREFIX ?= $(HOME)/.local
INSTALL_BIN ?= $(INSTALL_PREFIX)/bin
INSTALL_ETC ?= $(INSTALL_PREFIX)/etc
INSTALL_SHARE ?= $(INSTALL_PREFIX)/share
INSTALL_MAN ?= $(INSTALL_PREFIX)/share/man
INSTALL_DOC ?= $(INSTALL_PREFIX)/share/doc/rpk

all: check test

help:
	@echo "Available targets:"
	@echo "  make all         - Run check and test (default)"
	@echo "  make check       - Alias for lint"
	@echo "  make test        - Run all test files in t/"
	@echo "  make lint        - Lint all scripts with shellcheck"
	@echo "  make install     - Install scripts, etc, share, man, docs, and agent skills"
	@echo "  make install-bin - Install scripts to \$$INSTALL_BIN"
	@echo "  make install-etc - Install etc to \$$INSTALL_ETC"
	@echo "  make install-share - Install share to \$$INSTALL_SHARE"
	@echo "  make install-man - Install man pages to \$$INSTALL_MAN"
	@echo "  make install-doc - Install documentation to \$$INSTALL_DOC"
	@echo "  make install-skills - Install agent skills (Claude Code, opencode, raven)"
	@echo "  make clean       - Remove installed files"
	@echo ""
	@echo "Variables:"
	@echo "  INSTALL_PREFIX   - Installation prefix (default: ~/.local)"
	@echo "  INSTALL_ETC      - Configuration directory (default: PREFIX/etc)"

check: lint

test:
	@command -v bats >/dev/null 2>&1 || { echo "bats not installed — install with 'rpk rpk depends' or your package manager"; exit 1; }
	@if [ -n "$(TEST_FILES)" ]; then \
		bats $(TEST_FILES); \
	else \
		echo "no tests found in $(TEST_DIR)"; \
	fi

lint:
	@echo "Linting scripts..."
	@for script in $(SCRIPTS); do \
		if command -v shellcheck >/dev/null 2>&1; then \
			shellcheck "$$script" || true; \
		else \
			echo "shellcheck not installed, skipping $$script"; \
		fi \
	done

install: install-bin install-etc install-share install-man install-doc install-skills
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

install-doc:
	@echo "Installing documentation to $(INSTALL_DOC)..."
	@if [ -n "$(DOC_FILES)" ]; then \
		mkdir -p "$(DESTDIR)$(INSTALL_DOC)"; \
		for doc in $(DOC_FILES); do \
			cp "$$doc" "$(DESTDIR)$(INSTALL_DOC)/"; \
		done; \
	else \
		echo "no documentation found, skipping"; \
	fi

install-skills:
	@echo "Installing agent skills..."
	@if [ -f "$(SKILLS_DIR)/rpk-author/SKILL.md" ]; then \
		mkdir -p "$(DESTDIR)$(INSTALL_SHARE)/claude/skills/rpk-author"; \
		cp "$(SKILLS_DIR)/rpk-author/SKILL.md" "$(DESTDIR)$(INSTALL_SHARE)/claude/skills/rpk-author/SKILL.md"; \
		mkdir -p "$(DESTDIR)$(INSTALL_SHARE)/raven/skills/rpk-author"; \
		cp "$(SKILLS_DIR)/rpk-author/SKILL.md" "$(DESTDIR)$(INSTALL_SHARE)/raven/skills/rpk-author/SKILL.md"; \
	fi
	@if [ -f "$(SKILLS_DIR)/rpk-author/opencode.md" ]; then \
		mkdir -p "$(DESTDIR)$(INSTALL_SHARE)/opencode/commands"; \
		cp "$(SKILLS_DIR)/rpk-author/opencode.md" "$(DESTDIR)$(INSTALL_SHARE)/opencode/commands/rpk-author.md"; \
	fi
	@echo ""
	@echo "Activate per agent by symlinking from the user config dir:"
	@echo "  Claude Code:  ln -sf $(INSTALL_SHARE)/claude/skills/rpk-author \$$HOME/.claude/skills/rpk-author"
	@echo "  Raven:        ln -sf $(INSTALL_SHARE)/raven/skills/rpk-author \$$HOME/.raven/workspace/skills/rpk-author"
	@echo "  opencode:     ln -sf $(INSTALL_SHARE)/opencode/commands/rpk-author.md \$$HOME/.config/opencode/commands/rpk-author.md"

clean:
	@echo "Cleaning up..."
	@rm -rf $(INSTALL_PREFIX)/bin/rpk $(INSTALL_PREFIX)/etc/scripts $(INSTALL_PREFIX)/share/*
