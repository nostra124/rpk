---
id: BUG-004
type: bug
priority: low
status: done
---

# BUG-004: `command:package` has an unreachable `home` branch

## Severity
Low — dead code. Doesn't cause wrong behaviour, but makes the type
system inconsistent with what the rest of rpk enforces.

## Observed
`command:package` in `bin/rpk` dispatches on `$(command:type)`:

    if [ "$(command:type)" = "system" ]; then
        ...
    elif [ "$(command:type)" = "home" ]; then
        local PREFIX=$(command:bundle home)/$PACKAGE-$VERSION
    elif [ "$(command:type)" = "user" ]; then
        local PREFIX=$(command:bundle user)/$PACKAGE-$VERSION
    else
        fatal "unknown $SELF type of package $PACKAGE"
    fi

The `home` branch can never fire: `command:type` reads
`.rpk/rpk-type` or `.rpk/type`, and `command:init` only ever writes
`user` (and the documented vocabulary in `PACKAGING.md` is `user` or
`system`). `home` is a synonym accepted by `command:bundle` /
`command:target` for directory resolution, but it's not a valid
`.rpk/type` value.

## Root Cause
Leftover from when `home` and `user` were considered distinct types
rather than aliases at the path-accessor level.

## Fix plan
Collapse the if/elif/else into the two valid types:

    local PACKAGE_TYPE=$(command:type)
    case "$PACKAGE_TYPE" in
        system)
            [ "$EUID" -eq 0 ] || fatal "system packages have to be packaged as root user"
            ;;
        user)
            ;;
        *)
            fatal "unknown $SELF type of package $PACKAGE"
            ;;
    esac
    local PREFIX=$(command:bundle "$PACKAGE_TYPE")/$PACKAGE-$VERSION

## Regression Protection
No test needed — dead-branch removal. Covered by existing
`t/lifecycle.bats` packaging flow.
