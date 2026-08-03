#!/usr/bin/env bash
# Apply the umbrella branch-protection convention to a module repo's main.
# Run right after adding a new submodule:
#   bash .specify/scripts/bash/module-bootstrap.sh <module-name> [--dry-run]
# Idempotent: re-running re-applies the same settings (PUT).

set -euo pipefail

MODULE=""
DRY_RUN=false
CI_OVERRIDE=""

usage() {
    cat <<'EOF'
Usage: module-bootstrap.sh <module-name> [--dry-run] [--ci job1,job2]

Protect main of modulos/<module> on GitHub: 1 approving review + required CI
checks (auto-detected from .github/workflows/*.yml).

OPTIONS:
  --dry-run       Print the payload, change nothing
  --ci <jobs>     Comma-separated required check names (default: auto-detect)
  -h, --help      Show this help

Requires: gh authenticated with admin rights on the module repo.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --ci) CI_OVERRIDE="${2:-}"; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 1 ;;
        *) [[ -z "$MODULE" ]] && MODULE="$1" || { echo "ERROR: too many arguments" >&2; exit 1; } ;;
    esac
    shift
done

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO_ROOT="$(get_repo_root)" || { echo "ERROR: no spec-kit project root found" >&2; exit 1; }
[[ -n "$MODULE" ]] || { echo "ERROR: module name required" >&2; usage >&2; exit 1; }
MDIR="$REPO_ROOT/modulos/$MODULE"
[[ -d "$MDIR/.git" || -f "$MDIR/.git" ]] || { echo "ERROR: no git repo at modulos/$MODULE" >&2; exit 1; }

REMOTE="$(git -C "$MDIR" config --get remote.origin.url 2>/dev/null || true)"
REPO="$(echo "$REMOTE" | sed -E 's/\.git$//' | sed -E 's#.*github.com[:/]([^/]+/[^/]+)$#\1#')"
if [[ -z "$REPO" || "$REPO" == "$REMOTE" ]]; then
    echo "ERROR: cannot resolve GitHub repo from remote '$REMOTE' (modulos/$MODULE)" >&2
    exit 1
fi

if [[ -n "$CI_OVERRIDE" ]]; then
    CONTEXTS="$CI_OVERRIDE"
else
    CONTEXTS="$(python3 "$SCRIPT_DIR/ci_jobs.py" "$MDIR" 2>/dev/null || true)"
fi

PAYLOAD="$(CI_CONTEXTS="$CONTEXTS" python3 - <<'PY'
import json, os
contexts = [c for c in os.environ["CI_CONTEXTS"].split(",") if c]
payload = {
    "required_status_checks": {"strict": True, "contexts": contexts} if contexts else None,
    "required_pull_request_reviews": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews": True,
    },
    "enforce_admins": True,
    "allow_force_pushes": False,
    "allow_deletions": False,
    "required_linear_history": False,
    "restrictions": None,
}
print(json.dumps(payload))
PY
)"

echo "Repo: $REPO | required checks: ${CONTEXTS:-none}"
if [[ "$DRY_RUN" == true ]]; then
    echo "Would PUT $REPO/branches/main/protection with:"
    echo "$PAYLOAD"
    exit 0
fi

command -v gh >/dev/null 2>&1 || { echo "ERROR: gh not installed" >&2; exit 1; }
gh api -X PUT "repos/$REPO/branches/main/protection" --input <(echo "$PAYLOAD") >/dev/null
echo "Branch protection applied: $REPO:main (checks: $(gh api "repos/$REPO/branches/main/protection" --jq '.required_status_checks.contexts | join(",")') )"
