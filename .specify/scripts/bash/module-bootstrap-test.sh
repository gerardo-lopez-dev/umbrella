#!/usr/bin/env bash
# Self-check for module-bootstrap.sh: exercises CI job detection and the
# --dry-run payload resolution against a throwaway repo. No gh/network needed.
# Run from anywhere:  bash .specify/scripts/bash/module-bootstrap-test.sh

set -euo pipefail

HERE="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T=/tmp/opencode/module-bootstrap-selfcheck
rm -rf "$T"
mkdir -p "$T/.specify/scripts/bash" "$T/modulos/fake-service/.github/workflows"
cp "$HERE/common.sh" "$HERE/module-bootstrap.sh" "$HERE/ci_jobs.py" "$T/.specify/scripts/bash/"
printf '{"umbrella_fanout":{}}\n' > "$T/.specify/init-options.json"

cat > "$T/modulos/fake-service/.github/workflows/ci.yml" <<'EOF'
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
  lint:
    runs-on: ubuntu-latest
EOF

git -C "$T/modulos/fake-service" init -q
git -C "$T/modulos/fake-service" remote add origin git@github.com:owner/fake-service.git

assert() { local msg="$1"; shift; "$@" >/dev/null 2>&1 || { echo "FAIL: $msg"; exit 1; }; }

cd "$T"

jobs="$(python3 .specify/scripts/bash/ci_jobs.py modulos/fake-service)"
assert "ci_jobs parses job names" bash -c "echo '$jobs' | grep -q '^build,lint$'"

out="$(bash .specify/scripts/bash/module-bootstrap.sh fake-service --ci build --dry-run)"
assert "dry-run resolves the repo" bash -c "echo '$out' | grep -q 'owner/fake-service'"
assert "dry-run bakes the check into the payload" bash -c "echo '$out' | grep -q '\"build\"'"
assert "auto-detect feeds the payload" \
    bash -c "bash .specify/scripts/bash/module-bootstrap.sh fake-service --dry-run | grep -q 'required checks: build,lint'"

echo "module-bootstrap self-check: PASS"
