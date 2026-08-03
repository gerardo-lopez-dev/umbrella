#!/usr/bin/env bash
# Self-check for umbrella-root context resolution (SPECIFY_FEATURE_DIRECTORY /
# SPECIFY_INIT_DIR): proves every phase can target specs or a module from the
# umbrella root without cd. No network needed.
# Run from anywhere:  bash .specify/scripts/bash/context-test.sh

set -euo pipefail

HERE="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T=/tmp/opencode/context-selfcheck
rm -rf "$T"
mkdir -p "$T/.specify/scripts/bash" \
    "$T/modulos/specs-lib/.specify" \
    "$T/modulos/specs-lib/specs/NNN-fake"
cp "$HERE/common.sh" "$HERE/check-prerequisites.sh" "$T/.specify/scripts/bash/"
printf '{"umbrella_fanout":{}}\n' > "$T/.specify/init-options.json"
: > "$T/modulos/specs-lib/specs/NNN-fake/spec.md"

assert() { local msg="$1"; shift; "$@" >/dev/null 2>&1 || { echo "FAIL: $msg"; exit 1; }; }

cd "$T"

vals() { REPO_ROOT="$(sed -n 's/^REPO_ROOT: //p' <<< "$1")"; FEATURE_DIR="$(sed -n 's/^FEATURE_DIR: //p' <<< "$1")"; }

# 1) SPECIFY_FEATURE_DIRECTORY: specs context from the umbrella root (no cd)
out="$(SPECIFY_FEATURE_DIRECTORY=modulos/specs-lib/specs/NNN-fake \
    bash .specify/scripts/bash/check-prerequisites.sh --paths-only)"
vals "$out"
assert "REPO_ROOT is the umbrella, not the submodule" \
    bash -c "echo \"$REPO_ROOT\" | grep -q \"$T\$\""
assert "FEATURE_DIR resolves into modulos/specs-lib" \
    bash -c "echo \"$FEATURE_DIR\" | grep -q 'modulos/specs-lib/specs/NNN-fake'"

# 2) SPECIFY_INIT_DIR: a target with its own feature.json
printf '{"feature_directory":"specs/NNN-fake"}\n' > "$T/modulos/specs-lib/.specify/feature.json"
out2="$(SPECIFY_INIT_DIR=modulos/specs-lib \
    bash .specify/scripts/bash/check-prerequisites.sh --paths-only)"
vals "$out2"
assert "SPECIFY_INIT_DIR redirects REPO_ROOT to the target" \
    bash -c "echo \"$REPO_ROOT\" | grep -q 'modulos/specs-lib'"
assert "FEATURE_DIR resolves via the target's feature.json" \
    bash -c "echo \"$FEATURE_DIR\" | grep -q 'modulos/specs-lib/specs/NNN-fake'"

echo "context self-check: PASS"
