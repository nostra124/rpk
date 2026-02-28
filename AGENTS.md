# AGENTS.md - Developer Guide for rpk

This is a **bash-based package manager** project. The main executable is `bin/rpk` (a ~1200 line bash script).

## Build, Lint, and Test Commands

```bash
# Run all checks and tests (default target)
make all

# Lint all scripts with shellcheck
make lint
make check

# Run all test files in t/ directory
make test

# Run a single test file
bash t/<filename>.t

# Install scripts, etc, and share
make install

# Install to custom prefix
make install INSTALL_PREFIX=/custom/path
```

### Test Structure
- Test files are in `t/*.t` (shell scripts)
- Each test is executed directly with `bash`
- Tests should exit with code 0 on success, non-zero on failure

## Code Style Guidelines

### Shebang and Script Headers
```bash
#!/bin/bash

# First line should always be for debugging
[ -n "$SELF_DEBUG" ] && set -vx
```

### Naming Conventions
- **Global variables**: Uppercase (e.g., `VERSION`, `SELF`, `SELF_CONFIG`)
- **Local variables**: Lowercase with `local` keyword
- **Functions**: 
  - Utility functions: `function_name()` or name:subname() (e.g., `fatal()`, `debug()`, `rpk:stage-repo()`)
  - Commands: `command:name()` pattern (e.g., `command:help()`, `command:version()`)
- **Constants**: Uppercase (e.g., `NAT='0|[1-9][0-9]*'`)

### Error Handling
```bash
# Fatal errors - exit with code 1
fatal() {
    echo -e "$SELF - fatal: \033[31;m$@\033[0m" >&2
    exit 1
}

# For package/install scripts - exit with code 100
function die() {
    echo "$@"
    exit 100
}

# Debug output
debug() {
    [ -n "$SELF_DEBUG" ] && echo -e "$SELF - debug: \033[90;m$@\033[0m" >&2
}

# Info output (can be suppressed)
info() {
    [ ! -n "$SELF_QUIET" ] && echo -e "$SELF - info:  \033[32;m$@\033[0m" >&2
}

# Warnings
warn() {
    echo -e "$SELF - warn:  \033[33;1;m$@\033[0m" >&2
}
```

### Input Handling
```bash
# Use getopts for option parsing
while getopts "qdf" flag; do
    case "$flag" in
        q) SELF_QUIET=1 ;;
        d) SELF_DEBUG=1 ;;
        f) SELF_FORCE=1 ;;
    esac
done
shift $((OPTIND-1))
```

### Variable Defaults
```bash
: ${VARIABLE_NAME:=default_value}
```

### Directory Paths
Follow XDG Base Directory spec:
```bash
: ${XDG_CONFIG_HOME:="$HOME/.local/etc"}
: ${XDG_CACHE_HOME:="$HOME/.cache"}
: ${XDG_DATA_HOME:="$HOME/.local/var/lib"}
```

### Color Output
Use ANSI escape codes for colored output:
```bash
# Red (fatal errors)
echo -e "\033[31;m$@\033[0m"

# Gray (debug)
echo -e "\033[90;m$@\033[0m"

# Green (info)
echo -e "\033[32;m$@\033[0m"

# Yellow bold (warnings)
echo -e "\033[33;1;m$@\033[0m"
```

### Cleanup with Trap
```bash
BRANCH=$(git branch --show-current)
trap "git checkout $BRANCH --force" EXIT
```

### Checking Command Existence
```bash
# Check if command exists
if command -v somecommand >/dev/null 2>&1; then
    # use somecommand
fi

# Check if function exists
has() {
    local KIND=$1
    local NAME=$2
    type -t $KIND:$NAME | grep -q function
}
```

### Test for Files/Directories
```bash
# Check if directory exists and is a git repo
[ -d "$WORKTREE" -a ! -d "$WORKTREE/.git" ] && rm -rf "$WORKTREE"

# Check file existence
test -f "$SELF_CONFIG/ssh/$ACCOUNT.pub"
```

### Import/Dependency Pattern
Dependencies are in `.rpk/depends/<name>`:
```bash
#!/bin/bash

if [ -x /opt/local/bin/port ]; then
    which git > /dev/null || rpk action sudo port install git
elif [ -x /usr/bin/apt-get ]; then
    which git > /dev/null || rpk action sudo apt-get --yes install git
fi
```

### ShellCheck Compliance
Run `shellcheck` on all scripts. Common rules:
- Use `[[ ]]` instead of `[ ]` for tests
- Quote variables: `"$VAR"` not `$VAR`
- Use `$()` instead of backticks
- Declare functions with `function` keyword or `name()` consistently

### Package Structure
Packages (git repos) must provide:
- `depends/` - directory with scripts to fulfill prerequisites
- `package` - executable to package a specific version
- `install` - executable to install the package
- `version` - executable to retrieve current installed version
- `versions` - text file or executable to retrieve available versions

### Exit Codes
- `0` - Success
- `1` - General fatal error
- `100` - Package-specific errors (in package/install scripts)
- Negative codes for specific errors (e.g., `exit -1`)

### Code Organization
1. Configuration section (version, paths, defaults)
2. Utility functions (fatal, debug, info, warn, has)
3. Option parsing
4. Directory setup
5. Command functions (`command:name`)
6. Main command dispatch at end
