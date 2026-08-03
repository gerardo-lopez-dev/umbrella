#!/usr/bin/env bash
# In-house umbrella fan-out: create the feature branch in each affected module
# submodule. Contract per docs/WORKFLOW.md section 4 / 4.1. Manual git stays the
# documented fallback.

set -euo pipefail

# --- args ---
DRY_RUN=false
SWITCH=""             # "" = from config
BRANCH=""
PLAN=""
MODULES=()

usage() {
    cat <<'EOF'
Usage: fanout.sh [OPTIONS]

Fan out a feature branch to the affected module submodules.

OPTIONS:
  -b, --branch <name>  Feature branch to create (default: current branch of modulos/specs-lib)
  -m, --module <name>  Module to fan out into (repeatable; default: Affected Repositories
                       from --plan)
      --plan <file>    plan.md to read the Affected Repositories list from
      --switch <y|n>   Override the switch setting from init-options.json
      --dry-run        Print commands only, change nothing
  -h, --help           Show this help

CONFIG (.specify/init-options.json -> umbrella_fanout):
  type         repo kind, default "submodule" (informational)
  switch       create+checkout the branch, default true
  skip_branches  never fan out these names, default ["main","master"]
  exclude      module names to skip, default []

SAFETY: never switches a dirty working tree (skips and reports); existing
branches are left alone (idempotent re-runs).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        -b|--branch) BRANCH="${2:-}"; shift ;;
        --plan) PLAN="${2:-}"; shift ;;
        -m|--module) MODULES+=("${2:-}"); shift ;;
        --switch) SWITCH="${2:-}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

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

CFG_SWITCH="$(read_config switch true)"
CFG_SKIP="$(read_config skip_branches '["main","master"]')"
CFG_EXCLUDE="$(read_config exclude '[]')"
[[ -n "$SWITCH" ]] && CFG_SWITCH="$SWITCH"

# --- resolve branch ---
if [[ -z "$BRANCH" ]]; then
    if git -C "$REPO_ROOT/modulos/specs-lib" rev-parse --git-dir >/dev/null 2>&1; then
        BRANCH="$(git -C "$REPO_ROOT/modulos/specs-lib" symbolic-ref --short HEAD 2>/dev/null || true)"
    fi
fi
if [[ -z "$BRANCH" ]]; then
    echo "ERROR: no branch given (--branch) and modulos/specs-lib has none." >&2
    exit 1
fi

# --- resolve modules ---
if [[ ${#MODULES[@]} -eq 0 ]]; then
    if [[ -n "$PLAN" ]]; then
        # Affected Repositories section: heading then "- name" list items.
        mapfile -t MODULES < <(awk '
            /^#.*Affected Repositories/ {in_sec=1; next}
            in_sec && /^#/ {in_sec=0}
            in_sec && /^[[:space:]]*-[[:space:]]+/ {
                line=$0; sub(/^[[:space:]]*-[[:space:]]+/, "", line)
                sub(/[[:space:]].*$/, "", line)   # strip "(desc)"
                print line
            }
        ' "$PLAN" 2>/dev/null || true)
    fi
fi
if [[ ${#MODULES[@]} -eq 0 ]]; then
    echo "ERROR: no affected modules resolved. Pass -m <module> or a --plan whose" >&2
    echo "       Affected Repositories section lists the modules to fan out." >&2
    exit 1
fi

# --- config-derived skip list ---
if command -v python3 >/dev/null 2>&1; then
    mapfile -t CFG_EXCLUDE < <(python3 -c 'import json,sys; print("\n".join(json.loads(sys.argv[1])))' "$CFG_EXCLUDE" 2>/dev/null || true)
fi

is_skipped_branch() {
    local b="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import json,sys; sys.exit(0 if sys.argv[1] in json.loads(sys.argv[2]) else 1)' "$b" "$CFG_SKIP"
    else
        echo "$CFG_SKIP" | grep -q "\"$b\""
    fi
}

[[ -n "$BRANCH" ]] || { echo "ERROR: empty branch resolved" >&2; exit 1; }
if is_skipped_branch "$BRANCH"; then
    echo "Skipped: branch '$BRANCH' is in skip_branches ($CFG_SKIP)."
    exit 0
fi

# --- fan out ---
declare -a seen=()
skip_due_exclude() {
    local m="$1" i
    for i in "${CFG_EXCLUDE[@]}"; do [[ "$i" == "$m" ]] && return 0; done
    for i in "${seen[@]}"; do [[ "$i" == "$m" ]] && return 0; done
    return 1
}

echo "Fan out branch '$BRANCH':"
for m in "${MODULES[@]}"; do
    [[ -z "$m" ]] && continue
    if skip_due_exclude "$m"; then
        echo "  - $m: excluded (exclude=$CFG_EXCLUDE)"
        continue
    fi
    seen+=("$m")

    mdir="$REPO_ROOT/modulos/$m"
    if [[ ! -d "$mdir/.git" && ! -f "$mdir/.git" ]]; then
        echo "  - $m: SKIP (no git repo at modulos/$m)"
        continue
    fi

    if git -C "$mdir" rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null; then
        echo "  - $m: exists (branch '$BRANCH' already present)"
        continue
    fi

    # best-effort: never clobber a dirty working tree (includes untracked files)
    if [[ "$CFG_SWITCH" == "true" ]] && [[ -n "$(git -C "$mdir" status --porcelain 2>/dev/null)" ]]; then
        echo "  - $m: SKIP (dirty working tree — switch it manually)"
        continue
    fi

    if [[ "$DRY_RUN" == true ]]; then
        cmd="git -C modulos/$m fetch origin"
        [[ "$CFG_SWITCH" == "true" ]] && cmd="$cmd && git -C modulos/$m checkout -b $BRANCH"
        echo "  - $m: would run: $cmd"
    else
        git -C "$mdir" fetch origin >/dev/null 2>&1 || true
        if git -C "$mdir" checkout -b "$BRANCH" >/dev/null 2>&1; then
            echo "  - $m: created"
        else
            echo "  - $m: FAILED (checkout -b failed — do it manually)"
        fi
    fi
done

if [[ "$DRY_RUN" == true ]]; then
    echo "(dry-run — nothing was changed)"
fi
