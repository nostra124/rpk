.PHONY: all check check-sit test lint clean install install-bin install-etc install-share install-man install-doc install-skills install-skills-user uninstall-skills-user help

-include config.mk

SHELL := /bin/bash
BIN_DIR := $(CURDIR)/bin
ETC_DIR := $(CURDIR)/etc
SHARE_DIR := $(CURDIR)/share
MAN_DIR := $(CURDIR)/man
DOC_DIR := $(CURDIR)/docs
SKILLS_DIR := $(CURDIR)/skills
TEST_DIR := $(CURDIR)/tests/unit
SIT_DIR := $(CURDIR)/tests/sit

SCRIPTS := $(wildcard $(BIN_DIR)/*)
RPK_SCRIPTS := $(CURDIR)/.rpk/package \
               $(wildcard $(CURDIR)/.rpk/install) \
               $(wildcard $(CURDIR)/.rpk/delete) \
               $(wildcard $(CURDIR)/.rpk/depends/*)
MAN_PAGES := $(wildcard $(MAN_DIR)/*.1)
DOC_FILES := $(wildcard $(DOC_DIR)/*.md)
TEST_FILES := $(wildcard $(TEST_DIR)/*.bats)

INSTALL_PREFIX ?= $(HOME)/.local
INSTALL_BIN ?= $(INSTALL_PREFIX)/bin
INSTALL_ETC ?= $(INSTALL_PREFIX)/etc
INSTALL_SHARE ?= $(INSTALL_PREFIX)/share
INSTALL_MAN ?= $(INSTALL_PREFIX)/share/man
INSTALL_DOC ?= $(INSTALL_PREFIX)/share/doc/rpk

all: lint check

help:
	@echo "Available targets:"
	@echo "  make all         - Run lint and check (default)"
	@echo "  make check       - Run unit tests (bats in tests/unit/)"
	@echo "  make check-sit   - Run system integration tests (bats + podman)"
	@echo "  make test        - Alias for make check"
	@echo "  make lint        - Lint all scripts with shellcheck"
	@echo "  make install     - Install scripts, etc, share, man, docs, and agent skills"
	@echo "  make install-bin - Install scripts to \$$INSTALL_BIN"
	@echo "  make install-etc - Install etc to \$$INSTALL_ETC"
	@echo "  make install-share - Install share to \$$INSTALL_SHARE"
	@echo "  make install-man - Install man pages to \$$INSTALL_MAN"
	@echo "  make install-doc - Install documentation to \$$INSTALL_DOC"
	@echo "  make install-skills - Install agent skills (Claude Code, opencode, raven)"
	@echo "  make install-skills-user - Symlink installed skills into user agent dirs (opt-in)"
	@echo "  make uninstall-skills-user - Remove symlinks created by install-skills-user"
	@echo "  make clean       - Remove installed files"
	@echo ""
	@echo "Variables:"
	@echo "  INSTALL_PREFIX   - Installation prefix (default: ~/.local)"
	@echo "  INSTALL_ETC      - Configuration directory (default: PREFIX/etc)"

check: test

test:
	@command -v bats >/dev/null 2>&1 || { echo "bats not installed — install with 'rpk rpk depends' or your package manager"; exit 1; }
	@if [ -n "$(TEST_FILES)" ]; then \
		bats $(TEST_FILES); \
	else \
		echo "no tests found in $(TEST_DIR)"; \
	fi

check-sit:
	@command -v bats >/dev/null 2>&1 || { echo "bats not installed"; exit 1; }
	@command -v podman >/dev/null 2>&1 || { echo "podman not installed — skipping SIT"; exit 0; }
	@if [ -d "$(SIT_DIR)/suites" ] && ls "$(SIT_DIR)"/suites/*.bats >/dev/null 2>&1; then \
		bats "$(SIT_DIR)"/suites/*.bats; \
	else \
		echo "no SIT suites found in $(SIT_DIR)/suites"; \
	fi

lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not installed — install with 'rpk rpk depends' or your package manager"; exit 1; }
	@shellcheck --severity=warning $(SCRIPTS) $(RPK_SCRIPTS)

install: install-bin install-etc install-share install-man install-doc install-skills
	@echo "Installation complete."

install-bin:
	@echo "Installing scripts to $(INSTALL_BIN)..."
	@mkdir -p "$(DESTDIR)$(INSTALL_BIN)"
	@for script in $(SCRIPTS); do \
		install -m 0755 "$$script" "$(DESTDIR)$(INSTALL_BIN)/"; \
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
	@echo "Run 'make install-skills-user' to activate skills in user agent dirs that already exist,"
	@echo "or symlink manually:"
	@echo "  ln -sf $(INSTALL_SHARE)/claude/skills/rpk-author \$$HOME/.claude/skills/rpk-author"
	@echo "  ln -sf $(INSTALL_SHARE)/raven/skills/rpk-author \$$HOME/.raven/workspace/skills/rpk-author"
	@echo "  ln -sf $(INSTALL_SHARE)/opencode/commands/rpk-author.md \$$HOME/.config/opencode/commands/rpk-author.md"

# Opt-in: symlink the installed skill files into the user's agent dirs, but
# only if those dirs already exist (never create a dotfile tree on the user's
# behalf). Idempotent — safe to re-run.
install-skills-user:
	@claude_dir="$${HOME}/.claude/skills"; \
	 raven_dir="$${HOME}/.raven/workspace/skills"; \
	 opencode_dir="$${HOME}/.config/opencode/commands"; \
	 src_claude="$(INSTALL_SHARE)/claude/skills/rpk-author"; \
	 src_raven="$(INSTALL_SHARE)/raven/skills/rpk-author"; \
	 src_opencode="$(INSTALL_SHARE)/opencode/commands/rpk-author.md"; \
	 if [ -d "$$claude_dir" ] && [ -d "$$src_claude" ]; then \
	 	ln -snf "$$src_claude" "$$claude_dir/rpk-author"; \
	 	echo "activated Claude Code skill at $$claude_dir/rpk-author"; \
	 else \
	 	echo "skipping Claude Code: $$claude_dir not present or installed skill missing"; \
	 fi; \
	 if [ -d "$$raven_dir" ] && [ -d "$$src_raven" ]; then \
	 	ln -snf "$$src_raven" "$$raven_dir/rpk-author"; \
	 	echo "activated Raven skill at $$raven_dir/rpk-author"; \
	 else \
	 	echo "skipping Raven: $$raven_dir not present or installed skill missing"; \
	 fi; \
	 if [ -d "$$opencode_dir" ] && [ -f "$$src_opencode" ]; then \
	 	ln -snf "$$src_opencode" "$$opencode_dir/rpk-author.md"; \
	 	echo "activated opencode command at $$opencode_dir/rpk-author.md"; \
	 else \
	 	echo "skipping opencode: $$opencode_dir not present or installed command missing"; \
	 fi

# Inverse of install-skills-user: remove the symlinks, leave real files alone.
uninstall-skills-user:
	@for link in \
		"$${HOME}/.claude/skills/rpk-author" \
		"$${HOME}/.raven/workspace/skills/rpk-author" \
		"$${HOME}/.config/opencode/commands/rpk-author.md"; \
	 do \
	 	if [ -L "$$link" ]; then \
	 		rm -f -- "$$link"; \
	 		echo "removed $$link"; \
	 	fi; \
	 done

clean:
	@echo "Removing rpk-installed artefacts (targeted — won't touch other packages)..."
	@rm -f  -- "$(DESTDIR)$(INSTALL_BIN)/rpk"
	@rm -f  -- "$(DESTDIR)$(INSTALL_ETC)/bash_completion.d/rpk"
	@rm -f  -- "$(DESTDIR)$(INSTALL_MAN)/man1/rpk.1"
	@rm -rf -- "$(DESTDIR)$(INSTALL_DOC)"
	@rm -rf -- "$(DESTDIR)$(INSTALL_SHARE)/claude/skills/rpk-author"
	@rm -rf -- "$(DESTDIR)$(INSTALL_SHARE)/raven/skills/rpk-author"
	@rm -f  -- "$(DESTDIR)$(INSTALL_SHARE)/opencode/commands/rpk-author.md"
