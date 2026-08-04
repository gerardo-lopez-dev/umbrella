#!/usr/bin/env bash
# In-house spec branch guarantee: create the feature branch in modulos/specs-lib
# from origin/<base> (default "main" from umbrella_fanout config). Runs from the
# umbrella root. This is the specs-side counterpart of fanout.sh; the branch
# ALWAYS starts from origin/<base>, never from the pinned tag / local state.

set -euo pipefail

# --- args ---
DRY_RUN=false
FEATURE=""
BASE=""
FORCE=false

usage() {
    cat <<'EOF'
Usage: ensure-spec-branch.sh [OPTIONS]

Ensure the feature branch exists in modulos/specs-lib, created from
origin/<base> (default "main" from umbrella_fanout.base).

OPTIONS:
  -f, --feature <name>  Feature branch name (required, e.g. 002-docker)
      --base <branch>   Base branch to create the feature branch from
                        (default: "main" from config)
      --force           If the branch already exists, reset it to origin/<base>
                        (only when the working tree is clean)
      --dry-run         Print commands only, change nothing
  -h, --help            Show this help

SAFETY: never switches a dirty working tree; existing branches are left alone
unless --force (idempotent re-runs).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        -f|--feature) FEATURE="${2:-}"; shift ;;
        --base) BASE="${2:-}"; shift ;;
        --force) FORCE=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

[[ -n "$FEATURE" ]] || { echo "ERROR: --feature is required." >&2; usage >&2; exit 1; }

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO_ROOT="$(get_repo_root)" || { echo "ERROR: no spec-kit project root found" >&2; exit 1; }

# --- config from init-options.json (umbrella_fanout block) ---
read_config() {
    local key="$1" default="$2"
    python3 - "$REPO_ROOT/.specify/init-options.json" "$key" "$default" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
    value = data.get("umbrella_fanout", {}).get(sys.argv[2], json.loads(sys.argv[3]))
except Exception:
    value = json.loads(sys.argv[3])
print(json.dumps(value))
PY
}

CFG_BASE="$(read_config base '"main"')"
CFG_BASE="${CFG_BASE//\"/}"
CFG_SKIP="$(read_config skip_branches '["main","master"]')"
[[ -n "$BASE" ]] || BASE="$CFG_BASE"

SPECS_DIR="$REPO_ROOT/modulos/specs-lib"
if [[ ! -d "$SPECS_DIR/.git" && ! -f "$SPECS_DIR/.git" ]]; then
    echo "ERROR: no git repo at modulos/specs-lib" >&2
    exit 1
fi

is_skipped_branch() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import json,sys; sys.exit(0 if sys.argv[1] in json.loads(sys.argv[2]) else 1)' "$1" "$CFG_SKIP"
    else
        echo "$CFG_SKIP" | grep -q "\"$1\""
    fi
}

if is_skipped_branch "$FEATURE"; then
    echo "Skipped: branch '$FEATURE' is in skip_branches ($CFG_SKIP)."
    exit 0
fi

# --- dirty working tree guard (includes untracked files) ---
if [[ -n "$(git -C "$SPECS_DIR" status --porcelain 2>/dev/null)" ]]; then
    echo "ERROR: modulos/specs-lib has a dirty working tree — commit or stash first." >&2
    echo "       Run: git -C modulos/specs-lib status" >&2
    exit 1
fi

# --- branch already exists? ---
if git -C "$SPECS_DIR" rev-parse --verify --quiet "refs/heads/$FEATURE" >/dev/null; then
    if [[ "$FORCE" == true ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "specs-lib: would reset existing branch '$FEATURE' to origin/$BASE"
        else
            git -C "$SPECS_DIR" checkout -B "$FEATURE" "origin/$BASE" >/dev/null 2>&1 \
                && echo "specs-lib: reset '$FEATURE' to origin/$BASE" \
                || { echo "specs-lib: FAILED (reset to origin/$BASE)" >&2; exit 1; }
        fi
    else
        echo "specs-lib: exists (branch '$FEATURE' already present — leaving it alone)"
    fi
    exit 0
fi

# --- base resolution ---
BASE_REF=""
if git -C "$SPECS_DIR" rev-parse --verify --quiet "refs/remotes/origin/$BASE" >/dev/null; then
    BASE_REF="origin/$BASE"
elif git -C "$SPECS_DIR" rev-parse --verify --quiet "refs/heads/$BASE" >/dev/null; then
    BASE_REF="$BASE"
else
    echo "ERROR: base '$BASE' not found in modulos/specs-lib (local or origin)." >&2
    echo "       Run: git -C modulos/specs-lib fetch origin" >&2
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "specs-lib: would run: git -C modulos/specs-lib fetch origin"
    echo "specs-lib: would run: git -C modulos/specs-lib checkout -b $FEATURE $BASE_REF"
    echo "(dry-run — nothing was changed)"
    exit 0
fi

git -C "$SPECS_DIR" fetch origin >/dev/null 2>&1 || true
git -C "$SPECS_DIR" checkout -b "$FEATURE" "$BASE_REF" >/dev/null 2>&1 \
    && echo "specs-lib: created '$FEATURE' (base: $BASE_REF)" \
    || { echo "specs-lib: FAILED (checkout -b $FEATURE $BASE_REF)" >&2; exit 1; }
