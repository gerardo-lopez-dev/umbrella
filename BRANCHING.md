# Branching convention — GitHub Flow (all repos)

Every repo in this project (umbrella, specs, each module) follows **GitHub Flow**:
`main` is the only trunk and is always deployable/buildable; work happens on
short-lived feature branches that merge to `main` via PR and are deleted after
merge. No `develop`, no `release/*`, no `hotfix/*`.

> Why: the specs repo already plays the "integration stage" role through its
> `spec-vX.Y.Z` tags, so a `develop` branch would duplicate it. One trunk per
> repo keeps the umbrella fan-out simple (feature branches always born from
> `main`) and keeps Dependabot/CI pointing at a single branch.

## Rules (all repos)

1. `main` is the only trunk. Never commit to it directly.
2. Every change is a short-lived feature branch → PR → merge to `main` → delete
   the branch.
3. Branch names use the feature tag: `NNN-slug` (e.g. `001-spring-profiles`).
4. One branch name per feature across every repo it touches (same name, multiple
   repos — PRs line up).
5. A feature branch is always born from the current `main` of the repo it lives
   in — guaranteed by `fanout.sh`, whose default base is `main` (config
   `umbrella_fanout.base`, resolved to `origin/main` post-fetch).

## Per-repo nuances

| Repo | What `main` means | Extra |
|------|-------------------|-------|
| `specs` | The released spec set. | Never edit `main` directly (per `CONTRIBUTING.md`); merging a feature = new `spec-vX.Y.Z` tag + `CHANGELOG.md` entry. Features live in `specs/NNN-slug/`. |
| `<module>` | A buildable, tested state. | Consumes `specs` as a pinned submodule tag; moving the pointer is an explicit act (`main` never follows specs' `main`). |
| `umbrella` | Orchestration state (docs, config, submodule pointers). | No feature branches: the "feature" lives in specs + modules; umbrella just records the new pointers and doc updates. |

## Tags

- `specs` is versioned with `spec-vMAJOR.MINOR.PATCH` tags. Modules pin to tags,
  never to specs' `main`.
- Other repos are not tag-driven.

## Enforcement (GitHub branch protection on `main`)

Each module's `main` is protected: 1 approving review, CI checks required
(auto-detected from `.github/workflows/`), admins enforced, no force-push, no
deletions. Apply it when adding a new module:

```sh
bash .specify/scripts/bash/module-bootstrap.sh <module> --dry-run   # review first
bash .specify/scripts/bash/module-bootstrap.sh <module>             # apply (idempotent)
```

## References

- Workflow and fan-out: `docs/WORKFLOW.md` (sections 4 / 4.1).
- Spec change process: `CONTRIBUTING.md`.
- Example end-to-end flow: `docs/flujo-ejemplo-post01.md`.
