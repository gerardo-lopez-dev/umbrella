#!/usr/bin/env bash
# Self-check for ensure-spec-branch.sh: rebuilds a throwaway umbrella in /tmp
# and asserts the contract (branch from origin/base, dirty-tree guard,
# idempotency, --force reset, skip_branches, --base fallback).
# Run from anywhere:  bash .specify/scripts/bash/ensure-spec-branch-test.sh

set -euo pipefail

HERE="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/ensure-spec-branch.sh"
COMMON="$HERE/common.sh"
T=/tmp/opencode/ensure-spec-branch-selfcheck
rm -rf "$T"
mkdir -p "$T/.specify/scripts/bash" "$T/modulos/specs-lib" "$T/remote"
cp "$COMMON" "$SCRIPT" "$T/.specify/scripts/bash/"
printf '{"umbrella_fanout":{"type":"submodule","switch":true,"base":"main","skip_branches":["main","master"],"exclude":[]}}\n' \
    > "$T/.specify/init-options.json"

# bare "origin" for specs-lib
git -C "$T/remote" init -q --bare
git -C "$T/modulos/specs-lib" init -q \
    && git -C "$T/modulos/specs-lib" checkout -q -b main \
    && git -C "$T/modulos/specs-lib" commit -q --allow-empty -m init \
    && git -C "$T/modulos/specs-lib" remote add origin "$T/remote" \
    && git -C "$T/modulos/specs-lib" push -q origin main

cd "$T"
run() { bash .specify/scripts/bash/ensure-spec-branch.sh "$@"; }
fail() { echo "FAIL: $1"; exit 1; }

out="$(run --feature 002-docker)"
echo "$out" | grep -q "created" || fail "branch not reported as created"
git -C "$T/modulos/specs-lib" symbolic-ref --short HEAD | grep -q 002-docker || fail "not on 002-docker"
[ "$(git -C "$T/modulos/specs-lib" rev-parse main)" = "$(git -C "$T/modulos/specs-lib" rev-parse 002-docker)" ] \
    || fail "branch base != main"

# move origin/main forward, then verify a NEW branch picks it up
git -C "$T/modulos/specs-lib" checkout -q main
git -C "$T/modulos/specs-lib" commit -q --allow-empty -m newer
git -C "$T/modulos/specs-lib" push -q origin main

run --feature 003-next >/dev/null
[ "$(git -C "$T/modulos/specs-lib" rev-parse origin/main)" = "$(git -C "$T/modulos/specs-lib" rev-parse 003-next)" ] \
    || fail "003-next not based on latest origin/main"

out="$(run --feature 002-docker)"
echo "$out" | grep -q exists || fail "idempotent re-run did not report exists"

out="$(run --feature 002-docker --force)"
echo "$out" | grep -q reset || fail "--force did not report reset"
[ "$(git -C "$T/modulos/specs-lib" rev-parse origin/main)" = "$(git -C "$T/modulos/specs-lib" rev-parse 002-docker)" ] \
    || fail "--force did not move branch to origin/main"

out="$(run --feature main)"
echo "$out" | grep -q Skipped || fail "skip_branches guard not triggered"

touch "$T/modulos/specs-lib/untracked.txt"
if out="$(run --feature 004-dirty 2>&1)"; then
    fail "dirty working tree did not abort"
fi
echo "$out" | grep -q "dirty working tree" || fail "dirty guard message missing"
rm -f "$T/modulos/specs-lib/untracked.txt"

run --feature 005-dry --dry-run >/dev/null
if git -C "$T/modulos/specs-lib" rev-parse --quiet --verify refs/heads/005-dry >/dev/null 2>&1; then
    fail "dry-run created a branch"
fi

git -C "$T/modulos/specs-lib" checkout -q main
git -C "$T/modulos/specs-lib" commit -q --allow-empty -m base-develop
git -C "$T/modulos/specs-lib" branch -q devtest
run --feature 006-dev --base devtest >/dev/null
[ "$(git -C "$T/modulos/specs-lib" rev-parse devtest)" = "$(git -C "$T/modulos/specs-lib" rev-parse 006-dev)" ] \
    || fail "--base did not fall back to local branch"

echo "ensure-spec-branch self-check: PASS"
