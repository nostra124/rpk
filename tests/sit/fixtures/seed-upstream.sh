#!/bin/bash
# Seed a minimal buildable rpk package as the current user.
# Invoked during Dockerfile.ssh-upstream build as rpklocal.

set -e

mkdir -p "$HOME/.local/src/mypkg"
cd "$HOME/.local/src/mypkg"

cat > configure <<'CFG'
#!/bin/sh
for arg; do
	case "$arg" in --prefix=*) echo "PREFIX=${arg#*=}" > config.mk ;; esac
done
CFG
chmod +x configure

cat > Makefile <<'MK'
-include config.mk
PREFIX ?= /usr/local

.PHONY: all install
all: ;

install:
	@mkdir -p $(PREFIX)/bin
	@printf '#!/bin/sh\necho hello from mypkg\n' > $(PREFIX)/bin/hello-mypkg
	@chmod +x $(PREFIX)/bin/hello-mypkg
MK

echo "config.mk" > .gitignore

git init -q -b main
git config user.email "test@example.com"
git config user.name  "Test User"
git add .
git commit -q -m "initial"

rpk init >/dev/null
rpk mypkg patch >/dev/null
