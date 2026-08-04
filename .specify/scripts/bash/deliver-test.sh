#!/usr/bin/env bash
# Self-check for deliver.sh: exercises pure logic (next_version, parse_modules)
# and a --dry-run of the prs stage against a throwaway umbrella. No gh/network.
# Run from anywhere:  bash .specify/scripts/bash/deliver-test.sh

set -euo pipefail

HERE="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T=/tmp/opencode/deliver-selfcheck
rm -rf "$T"
mkdir -p "$T/.specify/scripts/bash" \
    "$T/modulos/specs-lib/specs/003-test/tasks" \
    "$T/modulos/microservice-template" \
    "$T/origins"
cp "$HERE/common.sh" "$HERE/deliver.sh" "$T/.specify/scripts/bash/"
printf '{"umbrella_fanout":{}}\n' > "$T/.specify/init-options.json"

fail() { echo "FAIL: $1"; exit 1; }

# --- specs-lib (main + tags + feature branch + feature dir) ---
git -C "$T/modulos/specs-lib" init -q
git -C "$T/modulos/specs-lib" checkout -q -b main
git -C "$T/modulos/specs-lib" commit -q --allow-empty -m init
git -C "$T/modulos/specs-lib" tag spec-v1.0.2
git -C "$T/modulos/specs-lib" checkout -q -b 003-test
git -C "$T/modulos/specs-lib" commit -q --allow-empty -m "feat(specs): 003-test"
printf '# Changelog\n\n## spec-v1.0.2 (2026-08-04)\n\n- Post 01\n' > "$T/modulos/specs-lib/CHANGELOG.md"

cat > "$T/modulos/specs-lib/specs/003-test/plan.md" <<'EOF'
# Implementation Plan: Test

## Affected Repositories

- microservice-template (base)
EOF
printf '# Tasks Org\n\n- [ ] T001 pendiente\n' > "$T/modulos/specs-lib/specs/003-test/tasks.md"
printf '# Tasks Mod\n\n- [ ] T002 pendiente\n' > "$T/modulos/specs-lib/specs/003-test/tasks/microservice-template.md"
printf '# Spec: Test Feature\n\n## User Stories\n' > "$T/modulos/specs-lib/specs/003-test/spec.md"

# --- module with a feature commit ahead of origin/main (bare remote) ---
git -C "$T/origins" init -q --bare
git -C "$T/modulos/microservice-template" init -q
git -C "$T/modulos/microservice-template" checkout -q -b main
git -C "$T/modulos/microservice-template" commit -q --allow-empty -m init
git -C "$T/modulos/microservice-template" remote add origin "$T/origins"
git -C "$T/modulos/microservice-template" push -q origin main
git -C "$T/modulos/microservice-template" checkout -q -b 003-test
git -C "$T/modulos/microservice-template" commit -q --allow-empty -m "feat: 003-test"
git -C "$T/modulos/microservice-template" commit -q --allow-empty -m "feat: 003-test"

cat > "$T/.gitmodules" <<'EOF'
[submodule "modulos/specs-lib"]
	path = modulos/specs-lib
[submodule "modulos/microservice-template"]
	path = modulos/microservice-template
EOF

cd "$T"

# prs --dry-run: plans the push + PRs and stops, but changes nothing
out="$(bash .specify/scripts/bash/deliver.sh 003-test --stage prs --dry-run 2>&1)"
echo "$out" | grep -q "would: git -C modulos/microservice-template push -u origin 003-test" \
    || fail "dry-run no planifica el push del módulo"
echo "$out" | grep -q "specs: gh pr create" || fail "dry-run no planifica el PR de specs"
echo "$out" | grep -q "NEXT ACTION" || fail "dry-run no dice qué mergear después"

git -C "$T/modulos/microservice-template" symbolic-ref --short HEAD | grep -q 003-test \
    || fail "dry-run cambió la rama del módulo"
git -C "$T/modulos/microservice-template" for-each-ref --format='%(refname:short)' refs/remotes/origin \
    | grep -q '^origin/003-test$' && fail "dry-run pusheó la rama" || true

# tag --dry-run: next patch version derived from spec-v1.0.2
out="$(bash .specify/scripts/bash/deliver.sh 003-test --stage tag --dry-run 2>&1)"
echo "$out" | grep -Eq "spec-v1\.0\.3" || fail "dry-run tag no calcula spec-v1.0.3"

echo "deliver self-check: PASS"