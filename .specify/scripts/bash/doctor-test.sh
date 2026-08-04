#!/usr/bin/env bash
# Self-check for doctor.sh: rebuilds a throwaway umbrella in /tmp and asserts
# the contract (materialization, dirty-tree detection, pin consistency,
# mismatch detection, feature observation). No network needed.
# Run from anywhere:  bash .specify/scripts/bash/doctor-test.sh

set -euo pipefail

HERE="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCTOR="$HERE/doctor.sh"
COMMON="$HERE/common.sh"
T=/tmp/opencode/doctor-selfcheck
rm -rf "$T"
mkdir -p "$T/.specify/scripts/bash" \
    "$T/modulos/specs-lib" \
    "$T/modulos/microservice-template/specs"
cp "$COMMON" "$DOCTOR" "$T/.specify/scripts/bash/"
printf '{"umbrella_fanout":{}}\n' > "$T/.specify/init-options.json"

git -C "$T" init -q

cat > "$T/.gitmodules" <<'EOF'
[submodule "modulos/specs-lib"]
	path = modulos/specs-lib
[submodule "modulos/microservice-template"]
	path = modulos/microservice-template
EOF

# specs-lib + module specs both "pinned" to spec-v1.0.2 (detached HEAD on tag)
git -C "$T/modulos/specs-lib" init -q
git -C "$T/modulos/specs-lib" checkout -q -b main
git -C "$T/modulos/specs-lib" commit -q --allow-empty -m init
git -C "$T/modulos/specs-lib" tag spec-v1.0.2
git -C "$T/modulos/specs-lib" checkout -q --detach spec-v1.0.2

git -C "$T/modulos/microservice-template/specs" init -q
git -C "$T/modulos/microservice-template/specs" checkout -q -b main
git -C "$T/modulos/microservice-template/specs" commit -q --allow-empty -m init
git -C "$T/modulos/microservice-template/specs" tag spec-v1.0.2
git -C "$T/modulos/microservice-template/specs" checkout -q --detach spec-v1.0.2

git -C "$T/modulos/microservice-template" init -q
git -C "$T/modulos/microservice-template" checkout -q -b main
git -C "$T/modulos/microservice-template" commit -q --allow-empty -m init
git -C "$T/modulos/microservice-template" checkout -q -b 002-docker
git -C "$T/modulos/microservice-template" commit -q --allow-empty -m feat
git -C "$T/modulos/microservice-template" checkout -q main

mkdir -p "$T/modulos/specs-lib/specs/002-docker"

# register the module's nested specs as a real gitlink (160000) so the parent
# sees it as a pinned submodule, not an unrecorded change
SS="$(git -C "$T/modulos/microservice-template/specs" rev-parse HEAD)"
git -C "$T/modulos/microservice-template" update-index --add --cacheinfo 160000,"$SS",specs
git -C "$T/modulos/microservice-template" commit -q --allow-empty -m "pin specs"

cd "$T"
run() { bash .specify/scripts/bash/doctor.sh "$@"; }
fail() { echo "FAIL: $1"; exit 1; }

out="$(run 2>&1)"
echo "$out" | grep -q "doctor: PASS" || fail "clean umbrella did not PASS"
echo "$out" | grep -q "spec-v1.0.2" || fail "pinned tag not reported"

# dirty tree detection
touch "$T/modulos/microservice-template/dirty.txt"
out="$(run 2>&1 || true)"
echo "$out" | grep -q "dirty working tree: modulos/microservice-template" || fail "dirty module not flagged"
echo "$out" | grep -q "doctor: FAIL" || fail "dirty umbrella did not FAIL"
rm -f "$T/modulos/microservice-template/dirty.txt"

# pin mismatch detection (spec-v1.0.1 on a DIFFERENT commit than spec-v1.0.2)
git -C "$T/modulos/microservice-template/specs" checkout -q -b tmpmain
git -C "$T/modulos/microservice-template/specs" commit -q --allow-empty -m ver1
git -C "$T/modulos/microservice-template/specs" tag spec-v1.0.1
git -C "$T/modulos/microservice-template/specs" checkout -q --detach spec-v1.0.1
out="$(run 2>&1 || true)"
echo "$out" | grep -q "MISMATCH" || fail "pin mismatch not flagged"
echo "$out" | grep -q "doctor: FAIL" || fail "mismatched umbrella did not FAIL"
git -C "$T/modulos/microservice-template/specs" checkout -q --detach spec-v1.0.2

# feature observation: reports the feature dir and the module branch
out="$(run --feature 002-docker 2>&1 || true)"
echo "$out" | grep -q "feature dir: modulos/specs-lib/specs/002-docker" || fail "feature dir not reported"
echo "$out" | grep -q "branch '002-docker' in modulos/microservice-template" || fail "module feature branch not reported"
echo "$out" | grep -q "no branch '002-docker' in modulos/specs-lib" || fail "specs-lib missing branch not flagged"

echo "doctor self-check: PASS"