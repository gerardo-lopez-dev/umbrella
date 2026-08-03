#!/usr/bin/env bash
# Self-check for fanout.sh: rebuilds a throwaway umbrella in /tmp and asserts
# the contract (plan parsing, dirty-tree skip, idempotency, skip_branches).
# Run from anywhere:  bash .specify/scripts/bash/fanout-test.sh

set -euo pipefail

HERE="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FANOUT="$HERE/fanout.sh"
COMMON="$HERE/common.sh"
T=/tmp/opencode/fanout-selfcheck
rm -rf "$T"
mkdir -p "$T/.specify/scripts/bash" "$T/modulos/specs-lib" \
    "$T/modulos/microservice-template" "$T/modulos/products-service" \
    "$T/specs/NNN-checkout"
cp "$COMMON" "$FANOUT" "$T/.specify/scripts/bash/"
printf '{"umbrella_fanout":{"type":"submodule","switch":true,"skip_branches":["main","master"],"exclude":[]}}\n' \
    > "$T/.specify/init-options.json"

git -C "$T/modulos/specs-lib" init -q && git -C "$T/modulos/specs-lib" checkout -q -b 001-checkout \
    && git -C "$T/modulos/specs-lib" commit -q --allow-empty -m init
git -C "$T/modulos/microservice-template" init -q \
    && git -C "$T/modulos/microservice-template" commit -q --allow-empty -m init
git -C "$T/modulos/products-service" init -q \
    && git -C "$T/modulos/products-service" commit -q --allow-empty -m init
touch "$T/modulos/products-service/dirty.txt"

cat > "$T/specs/NNN-checkout/plan.md" <<'EOF'
# Implementation Plan: checkout

## Affected Repositories

- microservice-template (base)
- products-service
EOF

cd "$T"
out="$(bash .specify/scripts/bash/fanout.sh --plan specs/NNN-checkout/plan.md)"

assert() { local msg="$1"; shift; "$@" >/dev/null 2>&1 || { echo "FAIL: $msg"; exit 1; }; }

assert "created branch in clean module" \
    bash -c "git -C '$T/modulos/microservice-template' symbolic-ref --short HEAD | grep -q 001-checkout"
assert "skipped dirty module" \
    bash -c "echo '$out' | grep -q 'products-service: SKIP'"
assert "idempotent re-run (exists)" \
    bash -c "bash .specify/scripts/bash/fanout.sh --plan specs/NNN-checkout/plan.md | grep -q 'microservice-template: exists'"
assert "skip_branches guard" \
    bash -c "bash .specify/scripts/bash/fanout.sh --branch main --plan specs/NNN-checkout/plan.md | grep -q Skipped"
assert "no affected modules -> errors, not all repos" \
    bash -c "! bash .specify/scripts/bash/fanout.sh --branch 002-other | grep -q microservice-template"
assert "dry-run changes nothing" \
    bash -c "git -C '$T/modulos/microservice-template' rev-parse --quiet --verify refs/heads/002-other; test \$? -ne 0"

echo "fanout self-check: PASS"
