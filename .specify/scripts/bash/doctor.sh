#!/usr/bin/env bash
# umbrella-doctor: preflight + final verification of the umbrella in one
# command. Replaces the hand-run Fase 0 and the "Verificación final" checklist
# of docs/COMO-HACER-UNA-FEATURE.md.
#
# Checks (in order): umbrella is a repo, submodules materialized, working trees
# clean, specs-lib and each module's nested specs pinned to a tag, and pin
# consistency (same spec tag across all pinned specs copies). With --fetch it
# also fetches everything and reports behind/ahead drift. With --feature it
# reports the observable state of one feature (branches, PRs, tags) — no ledger,
# everything read from git/gh.
#
# Run from anywhere:  bash .specify/scripts/bash/doctor.sh [--fetch] [--feature NNN-slug]

set -euo pipefail

HERE="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/common.sh"
REPO_ROOT="$(get_repo_root)" || { echo "doctor: no spec-kit root found" >&2; exit 1; }
cd "$REPO_ROOT"

FETCH=false
FEATURE=""

usage() {
    cat <<'EOF'
Usage: doctor.sh [OPTIONS]

Preflight + final verification of the umbrella.

OPTIONS:
  --fetch                Fetch umbrella + submodules (best-effort) and report drift
  --feature <NNN-slug>   Report the observable state of one feature
  -h, --help             Show this help

Exit code: 0 if all checks pass, 1 otherwise. Prints PASS/FAIL per section.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fetch) FETCH=true ;;
        --feature) FEATURE="${2:-}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "doctor: unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

FAIL=0
pass() { echo "  [ok] $*"; }
fail() { echo "  [X] $*"; FAIL=1; }

# submodules declared in .gitmodules (paths)
submodule_paths() {
    awk -F'= ' '/^\[submodule/ {IN=1; next} /^[ \t]*path/ && IN {print $2}' .gitmodules 2>/dev/null
}

is_git() { git -C "$1" rev-parse --git-dir >/dev/null 2>&1; }
clean() { [[ -z "$(git -C "$1" status --porcelain 2>/dev/null)" ]]; }

pinned_tag() { git -C "$1" describe --tags --exact-match HEAD 2>/dev/null || true; }

echo "== umbrella-doctor: $(basename "$REPO_ROOT") =="

echo "[submodules]"
if ! is_git "$REPO_ROOT"; then fail "no git repo at umbrella root"; else pass "umbrella is a git repo"; fi
MAPS="$(submodule_paths)"
if [[ -z "$MAPS" ]]; then
    fail "no submodules declared in .gitmodules"
else
    for p in $MAPS; do
        [[ -e "$p/.git" ]] && pass "materialized: $p" || fail "NOT materialized: $p (run: git submodule update --init --recursive)"
        if is_git "$p"; then
            clean "$p" && pass "clean: $p" || fail "dirty working tree: $p (git -C $p status)"
        fi
    done
    # nested specs of each module
    for p in $MAPS; do
        [[ "$p" == "modulos/specs-lib" ]] && continue
        if [[ -e "$p/specs/.git" ]]; then
            is_git "$p/specs" && pass "materialized: $p/specs"
            clean "$p/specs" && pass "clean: $p/specs" || fail "dirty working tree: $p/specs"
        else
            fail "missing nested specs: $p/specs"
        fi
    done
fi

echo "[pinning]"
if is_git "$REPO_ROOT/modulos/specs-lib"; then
    t="$(pinned_tag "$REPO_ROOT/modulos/specs-lib")"
    if [[ -n "$t" ]]; then pass "specs-lib pinned to $t"; else fail "specs-lib NOT on a tag (on $(git -C "$REPO_ROOT/modulos/specs-lib" symbolic-ref -q --short HEAD 2>/dev/null || echo 'detached HEAD, no tag'))"; fi
else
    fail "specs-lib is not a git repo"; t=""
fi

for p in $MAPS; do
    [[ "$p" == "modulos/specs-lib" ]] && continue
    [[ -e "$p/specs/.git" ]] || continue
    mt="$(pinned_tag "$p/specs")"
    if [[ -n "$mt" ]]; then
        pass "pin: $p/specs -> $mt"
        if [[ -n "$t" && "$mt" != "$t" ]]; then fail "MISMATCH: $p/specs ($mt) != specs-lib ($t) — re-pin both to the same tag"; fi
    else
        fail "pin: $p/specs NOT on a tag"
    fi
done

if [[ "$FETCH" == true ]]; then
    echo "[drift]"
    for p in $MAPS; do
        git -C "$p" fetch origin -q 2>/dev/null || true
        st="$(git -C "$p" status -sb 2>/dev/null | head -1)"
        case "$st" in
            *behind*) fail "behind origin: $p ($st)" ;;
            *ahead*) fail "ahead of origin — unmerged local commits: $p ($st)" ;;
            *) pass "in sync: $p" ;;
        esac
    done
    git fetch origin -q 2>/dev/null || true
    case "$(git status -sb | head -1)" in
        *behind*) fail "umbrella behind origin/main" ;;
        *ahead*) fail "umbrella ahead of origin/main" ;;
        *) pass "umbrella in sync with origin/main" ;;
    esac
fi

if [[ -n "$FEATURE" ]]; then
    echo "[feature: $FEATURE]"
    for p in $MAPS; do
        is_git "$p" || continue
        git -C "$p" rev-parse --verify -q "refs/heads/$FEATURE" >/dev/null 2>&1 \
            && pass "branch '$FEATURE' in $p" || fail "no branch '$FEATURE' in $p"
    done
    [[ -d "$REPO_ROOT/modulos/specs-lib/specs/$FEATURE" ]] \
        && pass "feature dir: modulos/specs-lib/specs/$FEATURE" \
        || fail "no feature dir: modulos/specs-lib/specs/$FEATURE"
    for r in "$REPO_ROOT/modulos/specs-lib" $(for p in $MAPS; do [[ "$p" != "modulos/specs-lib" ]] && echo "$p"; done); do
        repo="$(git -C "$r" config --get remote.origin.url 2>/dev/null || true)"
        repo="$(echo "$repo" | sed -E 's/\.git$//' | sed -E 's#.*github.com[:/]([^/]+/[^/]+)$#\1#')"
        if [[ -n "$repo" ]] && command -v gh >/dev/null 2>&1; then
            state="$(gh pr list --repo "$repo" --head "$FEATURE" --state all --json state,mergedAt --jq '.[0].state // "none"' 2>/dev/null || echo "none")"
            case "$state" in
                MERGED) pass "PR merged: $repo ($FEATURE)" ;;
                OPEN) fail "PR OPEN: $repo ($FEATURE) — merge it" ;;
                *) pass "no PR yet: $repo" ;;
            esac
        fi
    done
fi

if [[ "$FAIL" == 1 ]]; then
    echo "doctor: FAIL"
    exit 1
fi
echo "doctor: PASS"