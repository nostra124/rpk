# rpk - A Bash-Based Package Manager

rpk is a simple, bash-based package manager that treats git repositories as packages. It provides version management, dependency handling, and installation capabilities using GNU Stow for symlink-based deployments.

## Features

- **Git-based packages** - Every package is a git repository
- **Semantic versioning** - Built-in support for semver (X.Y.Z)
- **Dependency management** - Automatic dependency installation
- **Multiple installation targets** - User (`~/.local`) or system-wide (`/usr/local`)
- **Remote synchronization** - Pull/push packages from/to remote accounts via SSH
- **Shell completion** - Bash completion for all commands

## Installation

```bash
# Install to ~/.local (default)
make install

# Install to custom prefix
make install INSTALL_PREFIX=/custom/path
```

This installs:
- `bin/rpk` - The main executable
- `etc/bash_completion.d/rpk` - Bash completion
- `share/` - Shared data files

## Quick Start

```bash
# Show help
rpk help

# Initialize a new package in current git repo
rpk init

# List available packages
rpk list

# Stage a package (clone from bare repo)
rpk stage <package>

# Install a package
rpk install <package>

# Update a package to latest version
rpk update <package>
```

## Package Structure

A valid rpk package must provide the following in its git repository:

```
my-package/
├── .rpk/
│   ├── rpk-type        # "user" or "system"
│   ├── versions       # Available versions (one per line)
│   ├── package        # Executable to create the bundle
│   ├── install        # Executable to install the package
│   └── depends/       # Directory with dependency scripts
├── bin/               # Executables
├── etc/               # Configuration files
├── share/             # Shared data
└── command/           # Package-specific commands
```

### Package Scripts

**package** - Creates the bundle directory:
```bash
#!/bin/bash
VERSION=$1
TARGET=$(rpk bundle home)/my-package-$VERSION
mkdir -p $TARGET/bin
rsync -av bin/ $TARGET
```

**install** - Performs installation:
```bash
#!/bin/bash
VERSION=$1
# Installation steps
```

**depends/** - Dependency scripts (e.g., `depends/git`):
```bash
#!/bin/bash
which git > /dev/null || rpk action sudo apt-get --yes install git
```

## Commands

### General Options
- `-d` - Enable debug mode
- `-q` - Quiet mode (suppress info output)
- `-f` - Force mode

### Information Commands
| Command | Description |
|---------|-------------|
| `help [cmd]` | Show help for command |
| `version` | Show rpk version |
| `version <pkg>` | Show installed version of package |
| `versions <pkg>` | List available versions |
| `type <pkg>` | Show package type (user/system) |
| `list` | List all available packages |
| `show <pkg>` | Show package information |

### Version Commands
| Command | Description |
|---------|-------------|
| `major <pkg>` | Bump major version |
| `minor <pkg>` | Bump minor version |
| `patch <pkg>` | Bump patch version |
| `changelog <version>` | Show changelog for version |

### Package Sync Commands
| Command | Description |
|---------|-------------|
| `stage [pkgs]` | Stage package worktrees |
| `pull <pkg> [account]` | Pull from remote |
| `push <pkg> [account]` | Push to remote |
| `sync [account] [pkg]` | Sync with remote account |
| `drop <account> [pkg]` | Remove remote connection |

### Package Management Commands
| Command | Description |
|---------|-------------|
| `install <pkg> [version]` | Install package |
| `update [pkg]` | Update package(s) |
| `delete <pkg>` | Delete package |
| `package <pkg> [version]` | Create package bundle |
| `bundles [pkg]` | List packaged versions |
| `cleanup [pkg]` | Remove old versions |

### Dependency Commands
| Command | Description |
|---------|-------------|
| `depends <pkg>` | List dependencies |
| `depends <pkg> <script>` | Run dependency script |

### System Commands
| Command | Description |
|---------|-------------|
| `platform` | Show platform name |
| `upgrade` | Upgrade base system |
| `init` | Initialize package in current repo |

### Path Commands
| Command | Description |
|---------|-------------|
| `source` | Show packages source directory |
| `target <home\|system>` | Show target directory |
| `bundle <home\|system>` | Show bundle directory |

## Configuration

rpk follows the XDG Base Directory specification:

| Variable | Default (non-root) | Default (root) |
|----------|-------------------|----------------|
| `XDG_CONFIG_HOME` | `~/.local/etc` | `/etc` |
| `XDG_CACHE_HOME` | `~/.cache` | `/var/cache` |
| `XDG_DATA_HOME` | `~/.local/var/lib` | `/var/lib` |

Additional paths:
- `SELF_SOURCES` - Package source repos (`~/.local/src` or `/usr/local/src`)
- `SELF_DATA` - Package metadata (`~/.local/var/lib/rpk` or `/var/lib/rpk`)

## Development

### Running Tests

```bash
# Run all tests
make test

# Run a single test
bash t/<filename>.t
```

### Linting

```bash
# Lint all scripts
make lint

# Or use the alias
make check
```

### Building

```bash
# Run all checks and tests
make all
```

## Exit Codes

- `0` - Success
- `1` - General fatal error
- `100` - Package script error
- Negative codes - Specific command errors

## Examples

### Creating a New Package

```bash
# Initialize in a git repository
git init my-package
cd my-package
rpk init

# Add your package files to bin/, etc/, share/
# Edit .rpk/versions to add versions
# Create package and install scripts
```

### Installing a Package from Remote

```bash
# Sync from remote account
rpk sync user@host my-package

# Stage the package
rpk stage my-package

# Install it
rpk install my-package
```

### Updating Installed Packages

```bash
# Update a specific package
rpk update my-package

# Update all packages
rpk update
```

## License

See project repository for license information.
