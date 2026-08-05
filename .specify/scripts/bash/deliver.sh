#!/usr/bin/env bash
# deliver.sh — Fase 7 (deliver) del ciclo de feature. Nada de ledger: el estado
# se observa de git/gh, así que re-ejecutar tras una parada es seguro e
# idempotente. Reemplaza los pasos manuales de docs/COMO-HACER-UNA-FEATURE.md §7.
#
#   deliver.sh <feature> [--stage prs|tag|pin|close]   # corre una etapa concreta
#   deliver.sh <feature> --resume                      # corre la siguiente etapa pendiente
#   deliver.sh <feature> [--bump patch|minor|major]    # versión del tag (default: patch)
#   deliver.sh <feature> [--version spec-vX.Y.Z]       # versión explícita
#   deliver.sh <feature> [--title "<summary>"]         # sobreescribe el título del PR
#   deliver.sh <feature> [--dry-run]                   # imprime el plan, no cambia nada
#
# Etapas:
#   prs   push ramas de módulos + gh pr create por módulo y para specs
#         (marca tasks [X] + entrada en CHANGELOG). Para: tú mergeas.
#   tag   verifica que todos los PRs de feature están MERGED, crea el tag
#         spec-vX.Y.Z sobre main de specs y lo pushea.
#   pin   rama chore-spec-vX.Y.Z por módulo (sube su specs al tag) + rama
#         chore-spec-vX.Y.Z en el umbrella (specs-lib al tag, módulo a origin/main).
#   close verifica el merge del umbrella, corre doctor y limpia ramas locales.
#
# Los merges SIEMPRE los hace el humano (squash). Este script solo crea/pushea PRs.

set -euo pipefail

HERE="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/common.sh"

FEATURE=""
STAGE=""            # "" = resume
BUMP="patch"
VERSION=""
TITLE=""
DRY_RUN=false

usage() {
    cat <<'EOF'
Usage: deliver.sh <feature> [OPTIONS]

Stage options:
  --stage <prs|tag|pin|close>   Run a specific stage
  --resume                      Run the next pending stage (default if no --stage)
Version:
  --bump <patch|minor|major>    Next tag bump (default: patch)
  --version spec-vX.Y.Z         Explicit tag version
Other:
  --title "<summary>"           PR title override (default: derived from spec.md)
  --dry-run                     Print the plan, change nothing
  -h, --help                    Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stage) STAGE="${2:-}"; shift ;;
        --resume) STAGE="resume" ;;
        --bump) BUMP="${2:-}"; shift ;;
        --version) VERSION="${2:-}"; shift ;;
        --title) TITLE="${2:-}"; shift ;;
        --dry-run) DRY_RUN=true ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "deliver: unknown argument: $1" >&2; usage >&2; exit 1 ;;
        *) if [[ -z "$FEATURE" ]]; then FEATURE="$1"
           elif [[ "$1" =~ ^(prs|tag|pin|close)$ ]]; then STAGE="$1"
           else echo "deliver: too many arguments" >&2; exit 1; fi ;;
    esac
    shift
done

[[ -n "$FEATURE" ]] || { echo "deliver: feature required" >&2; usage >&2; exit 1; }

REPO_ROOT="$(get_repo_root)" || { echo "deliver: no spec-kit root found" >&2; exit 1; }
cd "$REPO_ROOT"

SPECS="$REPO_ROOT/modulos/specs-lib"
FEATDIR="$SPECS/specs/$FEATURE"
[[ -d "$FEATDIR" ]] || { echo "deliver: no feature dir: $FEATDIR" >&2; exit 1; }
[[ -n "$STAGE" ]] || STAGE="resume"
[[ "$BUMP" =~ ^(patch|minor|major)$ ]] || { echo "deliver: --bump debe ser patch|minor|major" >&2; exit 1; }

# --- helpers ---
submodule_paths() {
    awk -F'= ' '/^\[submodule/ {IN=1; next} /^[ \t]*path/ && IN {print $2}' .gitmodules 2>/dev/null
}
repo_of() { # path -> "owner/repo" (github) o vacío (remotes locales / sin gh)
    git -C "$1" config --get remote.origin.url 2>/dev/null \
        | sed -E 's/\.git$//' | sed -nE 's#.*github\.com[:/]([^/]+/[^/]+)$#\1#p' || true
}
parse_modules() { # plan.md -> módulos afectados
    awk '
        /^#.*Affected Repositories/ {in_sec=1; next}
        in_sec && /^#/ {in_sec=0}
        in_sec && /^[[:space:]]*-[[:space:]]+/ {
            line=$0; sub(/^[[:space:]]*-[[:space:]]+/, "", line)
            sub(/[[:space:]].*$/, "", line); print line
        }
    ' "$1" 2>/dev/null || true
}
latest_tag() {
    git -C "$1" tag -l 'spec-v*' 2>/dev/null | sort -V | tail -1
}
next_version() { # [specs-dir] [bump] [version]
    local dir="${1:-$SPECS}" bump="${2:-$BUMP}" ver="${3:-$VERSION}"
    if [[ -n "$ver" ]]; then echo "$ver"; return; fi
    local cur="$(latest_tag "$dir")"; cur="${cur#spec-v}"
    local IFS=. ; read -ra a <<< "$cur"
    a[0]="${a[0]:-0}"; a[1]="${a[1]:-0}"; a[2]="${a[2]:-0}"
    case "$bump" in
        major) echo "spec-v$((a[0]+1)).0.0" ;;
        minor) echo "spec-v${a[0]}.$((a[1]+1)).0" ;;
        *) echo "spec-v${a[0]}.${a[1]}.$((a[2]+1))" ;;
    esac
}
feature_version() { # primer tag cuya rama ya contiene la feature (vacío si nunca se taggeó)
    local tag
    while read -r tag; do
        if git -C "$SPECS" cat-file -e "$tag:specs/$FEATURE/spec.md" 2>/dev/null; then
            echo "$tag"; return
        fi
    done < <(git -C "$SPECS" tag -l 'spec-v*' | sort -V) || true
}
pr_state() { # repo branch -> OPEN | MERGED | none
    local repo="$1" branch="$2"
    [[ -n "$repo" ]] || { echo none; return; }
    command -v gh >/dev/null 2>&1 || { echo none; return; }
    gh pr list --repo "$repo" --head "$branch" --state all --json state --jq '.[0].state // "none"' 2>/dev/null || echo none
}
feature_title() { # salida: primera linea de heading de spec.md
    grep -m1 '^#' "$FEATDIR/spec.md" 2>/dev/null | sed -E 's/^#+[[:space:]]*//' || true
}
run() { # [desc] cmd
    if [[ "$DRY_RUN" == true ]]; then echo "  would: $*"; else eval "$*"; fi
}
stop() { echo; echo "NEXT ACTION (humano): $*"; echo; }

MERGED_OK=true
for m in $(parse_modules "$FEATDIR/plan.md"); do
    repo="$(repo_of "$REPO_ROOT/modulos/$m")"
    st="$(pr_state "$repo" "$FEATURE")"
    [[ "$st" == "MERGED" ]] || MERGED_OK=false
done
[[ "$(pr_state "$(repo_of "$SPECS")" "$FEATURE")" == "MERGED" ]] || MERGED_OK=false

# ================== stage: prs ==================
stage_prs() {
    echo "[prs] push + PRs para '$FEATURE' (afectados: $(parse_modules "$FEATDIR/plan.md" | tr '\n' ' '))"
    local mods; mods="$(parse_modules "$FEATDIR/plan.md")"
    local title="${TITLE:-$(feature_title)}"
    [[ -n "$title" ]] || title="$FEATURE"
    local body="Implementa $title del ROADMAP. Spec, plan y tasks en specs/$FEATURE."

    for m in $mods; do
        [[ -d "$REPO_ROOT/modulos/$m/.git" || -f "$REPO_ROOT/modulos/$m/.git" ]] || { echo "  - $m: SKIP (no module dir)"; continue; }
        local repo="$(repo_of "$REPO_ROOT/modulos/$m")"
        if git -C "$REPO_ROOT/modulos/$m" rev-parse -q "refs/heads/$FEATURE" >/dev/null 2>&1 \
           && [[ "$(git -C "$REPO_ROOT/modulos/$m" rev-parse "$FEATURE" 2>/dev/null)" != "$(git -C "$REPO_ROOT/modulos/$m" rev-parse origin/main 2>/dev/null)" ]]; then
            run "git -C modulos/$m push -u origin $FEATURE"
            if [[ "$DRY_RUN" != true ]]; then
                [[ "$(pr_state "$repo" "$FEATURE")" == "none" ]] \
                    && { echo "  - $m: gh pr create --repo $repo --title '$FEATURE: $title'"; gh pr create --repo "$repo" --title "$FEATURE: $title" --body "$body" >/dev/null; } \
                    || echo "  - $m: PR ya existe"
            else
                echo "  - $m: gh pr create --repo ${repo:-<remote>} --head $FEATURE"
            fi
        else
            echo "  - $m: SKIP (sin commits frente a origin/main)"
        fi
    done

    # specs: marca tasks [X] + changelog
    if [[ -d "$FEATDIR" ]]; then
        local version="$(next_version)"
        if [[ "$DRY_RUN" != true ]]; then
            git -C "$SPECS" rev-parse -q "refs/heads/$FEATURE" >/dev/null 2>&1 \
                || { echo "  deliver: sin rama '$FEATURE' en specs-lib" >&2; exit 1; }
            for tf in "$FEATDIR"/tasks.md "$FEATDIR"/tasks/*.md; do
                [[ -f "$tf" ]] && sed -i 's/^- \[ \]$/^- [X]/' "$tf"
            done
            if ! grep -q "^## $version " "$SPECS/CHANGELOG.md"; then
                local entry="## $version ($(date +%Y-%m-%d))

- $title — spec, plan y tasks (affected: $(echo "${mods:-specs only}" | tr '\n' ', ')). Implementado y verificado."
                python3 - "$SPECS/CHANGELOG.md" "$entry" <<'PY'
import sys
p, entry = sys.argv[1], sys.argv[2]
t = open(p, encoding="utf-8").read()
if entry.splitlines()[0] in t:
    sys.exit(0)
idx = t.index("# Changelog") + len("# Changelog")
t = t[:idx] + "\n\n" + entry + t[idx:]
open(p, "w", encoding="utf-8").writelines(t)
PY
            fi
            run "git -C modulos/specs-lib add specs/$FEATURE CHANGELOG.md"
            run "git -C modulos/specs-lib commit -m 'feat(specs): tasks $FEATURE completadas + changelog $version'"
            run "git -C modulos/specs-lib push -u origin $FEATURE"
            if [[ "$(pr_state "$(repo_of "$SPECS")" "$FEATURE")" == "none" ]]; then
                echo "  specs: gh pr create --repo $(repo_of "$SPECS") --title '$FEATURE: spec + tasks'"
                gh pr create --repo "$(repo_of "$SPECS")" --title "$FEATURE: spec + tasks" --body "$body" >/dev/null
            fi
        else
            run "git -C modulos/specs-lib add specs/$FEATURE CHANGELOG.md"
            run "git -C modulos/specs-lib commit -m 'feat(specs): tasks $FEATURE completadas + changelog $version'"
            run "git -C modulos/specs-lib push -u origin $FEATURE"
            echo "  specs: gh pr create --repo $(repo_of "$SPECS") --title '$FEATURE: spec + tasks'"
        fi
        stop "mergea los PRs de feature (módulo(s) + specs) con: gh pr merge --squash --delete-branch"
        return
    fi
}

# ================== stage: tag ==================
stage_tag() {
    echo "[tag] etapa tag"
    if [[ "$DRY_RUN" != true && "$MERGED_OK" != true ]]; then
        echo "  deliver: faltan PRs de feature por mergear. Revisa con: doctor.sh --feature $FEATURE"; exit 1
    fi
    local version="$(next_version)"
    if git -C "$SPECS" rev-parse -q "refs/tags/$version" >/dev/null 2>&1; then
        echo "  tag $version ya existe (skip)"
        return
    fi
    if [[ "$DRY_RUN" != true ]]; then        git -C "$SPECS" checkout -q main
        git -C "$SPECS" pull origin main -q 2>/dev/null || git -C "$SPECS" pull -q 2>/dev/null || true
        git -C "$SPECS" tag -a "$version" -m "$version: $FEATURE $(feature_title)"
        git -C "$SPECS" push origin "$version"
        git -C "$SPECS" checkout -q --detach "$version"
        echo "  tag $version creado y pusheado"
    else
        run "git -C modulos/specs-lib tag -a $version -m '$version: $FEATURE'"
        run "git -C modulos/specs-lib push origin $version"
    fi
}

# ================== stage: pin ==================
stage_pin() {
    local version="$1"
    if [[ -z "$version" ]]; then
        version="$(next_version)"
        git -C "$SPECS" rev-parse -q "refs/tags/$version" >/dev/null 2>&1 \
            || { echo "  deliver: tag $version no existe — corre deliver.sh $FEATURE --stage tag" >&2; exit 1; }
    fi
    echo "[pin] sube punteros a $version"
    local mods; mods="$(parse_modules "$FEATDIR/plan.md")"
    local chore="chore-$version"

    # 1) por módulo: rama chore-<ver> que sube SU specs al tag
    for m in $mods; do
        [[ -d "$REPO_ROOT/modulos/$m/.git" || -f "$REPO_ROOT/modulos/$m/.git" ]] || continue
        local repo="$(repo_of "$REPO_ROOT/modulos/$m")"
        if [[ "$(pr_state "$repo" "$chore")" != "none" ]]; then
            echo "  - $m: chore PR '$chore' ya existe ($(pr_state "$repo" "$chore"))"
            continue
        fi
        if [[ "$DRY_RUN" == true ]]; then
            run "git -C modulos/$m fetch origin"
            run "git -C modulos/$m checkout -b $chore origin/main"
            run "git -C modulos/$m/specs fetch origin"
            run "git -C modulos/$m/specs checkout $version"
            run "git -C modulos/$m add specs"
            run "git -C modulos/$m commit -m 'chore: pin specs a $version'"
            run "git -C modulos/$m push -u origin $chore"
            echo "  - $m: gh pr create --repo ${repo:-<remote>} --head $chore"
        else
            git -C "$REPO_ROOT/modulos/$m" fetch origin -q 2>/dev/null || true
            git -C "$REPO_ROOT/modulos/$m" checkout -q -b "$chore" origin/main 2>/dev/null \
                || git -C "$REPO_ROOT/modulos/$m" checkout -q -B "$chore" origin/main
            git -C "$REPO_ROOT/modulos/$m/specs" fetch origin -q 2>/dev/null || true
            git -C "$REPO_ROOT/modulos/$m/specs" checkout -q "$version" 2>/dev/null \
                || { echo "  - $m: no tag $version en el submodulo specs" >&2; }
            git -C "$REPO_ROOT/modulos/$m" add specs
            git -C "$REPO_ROOT/modulos/$m" commit -q -m "chore: pin specs a $version" \
                || echo "  - $m: sin cambios en specs (ya al tag)"
            git -C "$REPO_ROOT/modulos/$m" push -q -u origin "$chore" 2>/dev/null
            gh pr create --repo "$repo" --title "$chore: pin specs a $version" \
                --body "Re-pine el submodulo specs del módulo a $version." >/dev/null 2>&1
            echo "  - $m: chore PR creado"
        fi
    done
    if [[ -n "$mods" && "$DRY_RUN" != true ]]; then
        stop "mergea los PRs chore de módulo(s) ($chore): gh pr merge --repo <module> --squash --delete-branch"
        return
    fi

    # 2) umbrella: rama chore-<ver> que sube specs-lib al tag y módulo a origin/main
    local umb="$(repo_of "$REPO_ROOT")"
    if [[ "$(pr_state "$umb" "$chore")" != "none" ]]; then
        echo "  umbrella: chore PR '$chore' ya existe ($(pr_state "$umb" "$chore"))"
        return
    fi
    if [[ "$DRY_RUN" == true ]]; then
        run "git checkout main && git pull"
        run "git checkout -b $chore"
        run "git -C modulos/specs-lib fetch origin && git -C modulos/specs-lib checkout $version"
        for m in $mods; do run "git -C modulos/$m fetch origin && git -C modulos/$m checkout origin/main"; done
        run "git add modulos"
        run "git commit -m 'chore: pin specs a $version ($FEATURE)'"
        run "git push -u origin $chore"
        echo "  umbrella: gh pr create --title 'chore: pin specs a $version'"
    else
        git checkout -q main 2>/dev/null; git pull -q 2>/dev/null || true
        git checkout -q -b "$chore" 2>/dev/null || git checkout -q -B "$chore" main
        git -C "$SPECS" fetch origin -q 2>/dev/null || true
        git -C "$SPECS" checkout -q "$version"
        for m in $mods; do
            git -C "$REPO_ROOT/modulos/$m" fetch origin -q 2>/dev/null || true
            git -C "$REPO_ROOT/modulos/$m" checkout -q "origin/main"
        done
        git add modulos
        git commit -q -m "chore: pin specs a $version ($FEATURE)" || echo "  umbrella: sin cambios (ya al tag)"
        git push -q -u origin "$chore" 2>/dev/null
        gh pr create --title "chore: pin specs a $version" \
            --body "Absorbe $FEATURE: specs-lib y módulo(s) al tag $version." >/dev/null 2>&1
        echo "  umbrella: chore PR creado"
    fi
    stop "mergea el PR chore del umbrella ($chore): gh pr merge --squash --delete-branch"
}

# ================== stage: close ==================
stage_close() {
    echo "[close] version done"
    local version="$(feature_version)"
    [[ -n "$version" ]] || version="$(next_version)"
    local umb="$(repo_of "$REPO_ROOT")"
    if [[ "$(pr_state "$umb" "chore-$version")" != "MERGED" ]]; then
        echo "  deliver: el PR chore del umbrella no está MERGED aún"; exit 1
    fi
    echo "  doctor:"
    bash "$HERE/doctor.sh" --fetch || true
    echo "  ramas locales a limpiar (remoto ya borrado → mergeada):"
    for path in "$SPECS" $(for p in $(submodule_paths); do [[ "$p" != "modulos/specs-lib" ]] && echo "$REPO_ROOT/$p"; done); do
        [[ -d "$path" ]] || continue
        [[ "$DRY_RUN" != true ]] && git -C "$path" fetch -q --prune origin 2>/dev/null || true
        for b in $(git -C "$path" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null); do
            [[ "$b" == "main" || "$b" == "master" ]] && continue
            [[ "$b" == "$(git -C "$path" symbolic-ref -q --short HEAD 2>/dev/null || echo '')" ]] && continue
            if ! git -C "$path" show-ref --verify --quiet "refs/remotes/origin/$b" 2>/dev/null; then
                echo "    - git -C ${path#$REPO_ROOT/} branch -D $b"
                [[ "$DRY_RUN" != true ]] && git -C "$path" branch -D -q "$b"
            fi
        done
    done
    echo "[close] listo. Verifica: bash .specify/scripts/bash/doctor.sh --fetch"
}

# ================== dispatch ==================
case "$STAGE" in
    prs) stage_prs ;;
    tag) stage_tag ;;
    pin) stage_pin "$VERSION" ;;
    close) stage_close ;;
    resume)
        # --- punto de entrada por defecto: observa y corre lo que toca ---
        mods="$(parse_modules "$FEATDIR/plan.md")"
        fver="$(feature_version)"          # versión en la que esta feature ya fue taggeada

        if [[ -z "$fver" ]]; then
            # feature NO entregada aún: pipeline prs -> tag -> pin -> close
            version="$(next_version)"
            specs_repo="$(repo_of "$SPECS")"
            umb="$(repo_of "$REPO_ROOT")"
            for m in $mods; do
                repo="$(repo_of "$REPO_ROOT/modulos/$m")"
                st="$(pr_state "$repo" "$FEATURE")"
                case "$st" in
                    none) stage_prs; exit 0 ;;
                    MERGED) ;;
                    *) echo "STOP: mergea el PR de $m ($FEATURE)"; exit 0 ;;
                esac
            done
            sst="$(pr_state "$specs_repo" "$FEATURE")"
            case "$sst" in
                none) stage_prs; exit 0 ;;
                MERGED) ;;
                *) echo "STOP: mergea el PR de specs ($FEATURE)"; exit 0 ;;
            esac
            if ! git -C "$SPECS" rev-parse -q "refs/tags/$version" >/dev/null 2>&1; then
                stage_tag; stage_pin "$version"; exit 0
            fi
        else
            # feature YA taggeada en $fver: solo quedan chores/close
            version="$fver"
            umb="$(repo_of "$REPO_ROOT")"
        fi

        for m in $mods; do
            repo="$(repo_of "$REPO_ROOT/modulos/$m")"
            cst="$(pr_state "$repo" "chore-$version")"
            case "$cst" in
                none) stage_pin "$version"; exit 0 ;;
                MERGED) ;;
                *) echo "STOP: mergea el chore PR de $m (chore-$version)"; exit 0 ;;
            esac
        done
        ust="$(pr_state "$umb" "chore-$version")"
        case "$ust" in
            none) stage_pin "$version"; exit 0 ;;
            MERGED) stage_close; ;;
            *) echo "STOP: mergea el chore PR del umbrella (chore-$version)"; exit 0 ;;
        esac
        ;;
    *) echo "deliver: --stage desconocido: $STAGE" >&2; usage >&2; exit 1 ;;
esac