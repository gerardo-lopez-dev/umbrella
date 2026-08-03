# Workflow — Spec-Driven Development across modules

How the umbrella + specs repo + module repos work together, end to end. The
binding rules (pinning, cascade, spec-change flow) live in `AGENTS.md` and
`CONTRIBUTING.md`; this document is the runnable procedure.

> **Decisions:**
> - **Branching convention:** GitHub Flow in every repo — `main` as the only
>   trunk, short-lived feature branches merged via PR and deleted after merge.
>   No `develop`/`release`/`hotfix` branches. See `BRANCHING.md`.
> - **No third-party speckit preset/extension.** The community tools
>   (`multi-repo-sync` extension, `multi-repo-branching` preset) exist and are
>   documented in `docs/multi-repo-speckit-verification.md` as research
>   reference only. They are unproven for this setup and add upgrade-fragile
>   automation.
> - **Automation is built in-house, by us.** Branch fan-out is manual with plain
>   `git` (section 4) by default; when it needs automation, we **must** write
>   our own speckit extension (section 4.1) — owned, tested, and maintained by
>   us. A third-party dependency is never added for this.

---

## 1. Roles of the repos

| Repo | Role |
|------|------|
| `umbrella` | Orchestrates. Holds docs, rules (`AGENTS.md`, `CONTRIBUTING.md`), and the module submodules. No implementation. |
| `specs` | Source of truth. Requirements, contracts, plans, global constitution. Versioned with tags `spec-vMAJOR.MINOR.PATCH`. |
| `<module>` | Implementation. Consumes `specs` as a pinned git submodule at `modulos/<module>/specs`. |

The `specs` repo is mounted twice: at `modulos/specs-lib` (umbrella reference)
and at `modulos/<module>/specs` (each module's working copy). Both are pinned to
the same tag.

## 1.1 Operating model — everything from the umbrella root

The umbrella is the **only** session workspace. Never `cd` into a submodule or
start a session inside one; every phase runs from the umbrella root:

- **Files** are reached with umbrella-relative paths (`modulos/specs-lib/...`,
  `modulos/<module>/...`).
- **Submodule git** uses `git -C modulos/<m> ...`.
- **GitHub** uses `gh` with the repo resolved from the submodule's remote.
- **Speckit context** resolves via `SPECIFY_FEATURE_DIRECTORY=modulos/<target>/...`
  (override supported by `get_feature_paths`); `SPECIFY_INIT_DIR` only when the
  target has its own `.specify/feature.json`.

Single entry point: `/speckit.umbrella.run <target> <phase>`.

| Target | Root on disk | Phases |
|--------|--------------|--------|
| `specs` | `modulos/specs-lib` | `specify`, `plan`, `tasks` |
| `umbrella` | `.` | `fanout` (branch to affected modules) |
| `<module>` | `modulos/<module>` | `implement`, `verify` |

Example: `/speckit.umbrella.run microservice-template implement` implements the
module's tasks (from `.agent-context` → its task file under the module-mounted
specs) without leaving the umbrella root.

---

## 2. Getting started: configure the umbrella (step-by-step)

One commit per step, with explicit confirmation between steps. **Do not skip
ahead.**

### Prerequisites

- `specify` CLI installed (verified: v0.14.2). Check with `specify --version`.
- `gh` CLI authenticated (`gh auth status`) — to create/inspect repos.
- Git + SSH keys configured (`ssh -T git@github.com`).
- GitHub repos you own: `umbrella` (this one) exists. You need to decide the
  specs repo name (proposed: `specs`) and the first module repo (proposed:
  `microservice-template`).

### Step 0 — Gather the repo data

Ask/confirm before running anything that needs them (never invent URLs):
- Specs repo name + URL (`gerardo-lopez-dev/specs`?).
- First module repo name + URL (`gerardo-lopez-dev/microservice-template`?).
- Tag to pin everything to: `spec-v1.0.0`.

### Step 1 — Spec Kit + global constitution

```sh
specify init --here --integration opencode
```

Generates `.specify/memory/constitution.md` in the umbrella with GLOBAL
principles (code quality, cross-module testing standards, shared architecture
criteria — nothing stack-specific yet).
→ Commit: `chore: init spec kit + constitution global`

### Step 2 — Create the specs repo

If it does not exist, create it with:

```
<specs>/
├── .specify/memory/constitution.md   (same content as Step 1's global)
├── specs/
├── CHANGELOG.md
└── README.md
```

Tag it `spec-v1.0.0` and push.

### Step 3 — Pin specs-lib

```sh
git submodule add <url-repo-specs> modulos/specs-lib
git -C modulos/specs-lib checkout spec-v1.0.0
git add .gitmodules modulos/specs-lib && git commit -m "chore: agrega specs-lib pineado a spec-v1.0.0"
```

Confirm in one line that it is pinned to the tag, not `main`.

### Step 4 — Add the first module (repeat per module)

```sh
git submodule add <url-repo-module> modulos/<module>
git -C modulos/<module> submodule add <url-repo-specs> specs
git -C modulos/<module>/specs checkout spec-v1.0.0
```

Then create `.specify/memory/.agent-context` inside the module, pointing at the
`specs/specs/` folder that applies to it. Create a local `constitution.md` ONLY
if there are real overrides (e.g. the module's language test framework);
otherwise skip it.
→ Commit: `chore: agrega modulo <module> con specs pineado`

Apply the branch-protection convention to the new module's `main` (GitHub Flow,
`BRANCHING.md`) — idempotent, auto-detects the CI checks:

```sh
bash .specify/scripts/bash/module-bootstrap.sh <module> --dry-run   # review first
bash .specify/scripts/bash/module-bootstrap.sh <module>             # apply
```
→ Commit: `chore: configura branch protection de <module> (main)`

### Step 5 — Document the constitution cascade

In the umbrella `README.md`, write the reading order for anyone implementing
inside a module: global first (`modulos/<module>/specs/.specify/memory/...`),
local overrides second (`modulos/<module>/.specify/memory/...`) if present.
→ Commit: `docs: documenta orden de lectura de constitution en cascada`

### Step 6 — Spec-change process

`CONTRIBUTING.md` at the root documents the spec-change flow (PR → review →
tag + CHANGELOG → each module updates its pointer when it decides).
→ Commit: `docs: agrega proceso de cambio de spec en CONTRIBUTING.md`

### Step 7 — Our own automation (in-house extension)

Build our own speckit extension that wraps the manual fan-out of section 4 —
never a third-party one. See section 4.1 for the full build plan.
✅ **Done:** the `umbrella-fanout` extension is scaffolded, registered, and
wired to the `after_plan` / `after_tasks` hooks (see 4.1). The manual procedure
in section 4 remains the documented fallback.
→ Commit per unit of work of the extension.

### Step 8 — Verify

- Show the full repo tree with all submodules.
- Show `git log --oneline` of this session's commits.
- List anything pending on you (remote repos created, branch protection on the
  specs repo, permissions).

No commit in this step — it is a summary.

### Where spec.md / plan.md / tasks.md live

Features are authored in the **specs repo** (the speckit project). A feature is
a directory under `specs/`:

```
<specs>/
├── .specify/memory/constitution.md
├── specs/
│   └── 001-users-domain/
│       ├── spec.md              ← the feature spec
│       ├── data-model.md
│       ├── contracts/api.yaml
│       ├── plan.md              ← includes Affected Repositories (fan-out)
│       ├── tasks.md             ← shared/orchestration tasks
│       └── tasks/
│           ├── users-service.md ← per-module task file
│           └── ...
├── CHANGELOG.md
└── README.md
```

It is mounted in two places:

- Umbrella reference: `modulos/specs-lib/specs/001-users-domain/`.
- Each module: `modulos/<module>/specs/specs/001-users-domain/`. The module's
  `.specify/memory/.agent-context` points at its task file, e.g.
  `specs/specs/001-users-domain/tasks/users-service.md`.

`/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.verify` run in
the **specs repo**. `/speckit.implement` runs inside each module.

### One feature, many repos (backend + bff + frontend)

The spec is per **feature**, not per module. A cross-cutting feature keeps ONE
spec and splits only the tasks:

```
specs/NNN-checkout-flow/
├── spec.md              ← ONE spec for all three layers
├── plan.md              ← Affected Repositories: backend, bff, frontend
├── tasks.md             ← shared/orchestration tasks
└── tasks/
    ├── backend.md       ← task file for the backend repo
    ├── bff.md           ← task file for the BFF repo
    └── frontend.md      ← task file for the frontend repo
```

`/speckit.specify` and `/speckit.plan` run once for the feature. The fan-out
(section 4) creates the branch in every affected repo; each repo's
`.agent-context` points at its own task file; all repos implement in parallel
against the same spec and the same constitution.

### ROADMAP mapping

`docs/ROADMAP.md` is the content backlog; the umbrella is the delivery
machinery. They compose:

- Each Post (or logical group) becomes a feature in the specs repo:
  `specs/NNN-<post-slug>/`.
- The **affected module(s)** per post decide the fan-out:
  - Posts 01–17 → `microservice-template` (shared template base).
  - Fase A (18–21) → `users-service`, Fase B → `products-service`, … Fase G →
    `notifications-service` (per the ROADMAP service table).
- Cross-cutting phases (Sagas, CQRS/ES, Observability, Production) touch
  multiple modules → recorded in `plan.md` as affected repositories.
- Per-module implementation uses the ROADMAP's opencode skills
  (`/hexagonal.scaffold`, `/hexagonal.add-entity`, `/orders.add-state`, …).
  Those 13 skills are ROADMAP deliverables and must be created before first
  use; they are what `/speckit.implement` runs inside a module.

---

## 3. Feature lifecycle

1. **Init** — `specify init --here --integration opencode` (done at
   bootstrap; per-project if the specs repo is its own speckit project).
2. **Specify** — `/speckit.specify` creates the feature branch in the specs
   repo and the feature directory (`specs/NNN-name/`).
3. **Plan** — `/speckit.plan` generates `spec.md`, `data-model.md`, contracts,
   and `plan.md`. In `plan.md`, record an **Affected Repositories** list: every
   module whose implementation will change.
4. **Fan out branches (manual git)** — see section 4.
5. **Tasks** — `/speckit.tasks` generates `tasks.md` (shared/orchestration) and,
   for multi-repo features, per-module task files under `specs/NNN-name/tasks/`.
   Each module's `.specify/memory/.agent-context` points at its task file.
6. **Implement per module** — in `modulos/<module>`, run `/speckit.implement`.
   The agent reads the constitution cascade (global from `specs/.specify/...`,
   then local overrides) and executes only the tasks from its own task file.
7. **Verify** — `/speckit.verify` per module and for the feature.
8. **Deliver** —
   - PR per module (implementation) → merge.
   - PR in the specs repo (check off tasks, update contracts) → merge.
   - Tag the specs repo (`spec-vX.Y.Z`) + `CHANGELOG.md` entry.
   - Each module explicitly updates its `specs/` submodule pointer to the new
     tag when it decides to (section 5). Never automatic.

## 3.1 Multi-developer workflow

The specs repo is the single shared coordination point. Every developer mounts
the same specs repo (as a submodule), so **specs are the only mutable state
everyone touches** — the branching and review rules below are what keep N
developers from stepping on each other.

Branching model in the specs repo:

- `main` holds approved specs; tags `spec-vX.Y.Z` mark released versions.
- Each feature gets its own branch in the specs repo (e.g. `001-auth-backend`),
  created by `/speckit.specify`.
- If several developers work on the same feature, they branch off the feature
  branch with per-owner working branches (`001-auth-backend`, `001-auth-api`)
  and PR back into the feature branch.
- `plan.md`'s **Affected Repositories** tells everyone which modules coordinate
  on the feature.

Each developer's day:

1. Sync the workspace: `git submodule update --init --recursive`.
2. Their feature branch exists in the specs repo (or they create it).
3. Fan out the feature branch to the affected module(s) (section 4).
4. In their module, check out the feature branch in the module's `specs/`
   submodule so they work against the feature spec.
5. `/speckit.implement` in the module: reads `.agent-context` → own task file →
   constitution cascade → implements.
6. `/speckit.verify`.
7. Open PRs: one per module; in the specs repo, a PR from the feature branch
   into `main`. On merge, tag `spec-vX.Y.Z` and update `CHANGELOG.md`.

Why this avoids conflicts:

- Features live in their own directory (`specs/NNN-name/`); two developers
  editing different features touch different files.
- The specs repo's branch protection is the gate: nothing reaches `main`
  without review.
- Modules never edit a pinned spec in place — they work on a feature branch
  inside the submodule, and only absorb a new spec by moving their pointer to a
  released tag (section 5).

Shared-module coordination:

- Two developers in the same module work from separate task files under
  `specs/NNN-name/tasks/` (one per module) — a single task file per module
  keeps responsibility unambiguous.
- The module's own branch is the shared workspace; changes reach it through the
  module's normal PR flow before anything touches the shared spec.

## 4. Branch fan-out (manual git — our own)

When `plan.md` lists the affected modules, create the feature branch in the
specs repo and in each affected module:

```sh
# umbrella root — make sure submodules are present
git submodule update --init --recursive

# specs repo (via the umbrella reference)
git -C modulos/specs-lib fetch origin
git -C modulos/specs-lib checkout -b <feature-branch>

# each affected module
for m in users products orders; do
  git -C modulos/$m fetch origin
  git -C modulos/$m checkout -b <feature-branch>
done
```

Notes:
- A module can be left on its own branch if the feature does not touch it —
  fan-out only what the plan marks as affected.
- `git submodule update --init --recursive` also materializes each module's
  `specs/` submodule before work starts.
- Same branch name everywhere so PRs line up. Different repos, one branch name.

## 4.1 Own automation (in-house extension) — build plan

The commands in section 4 are the contract. Our own extension wraps them,
following the hook-based design (verified against `multi-repo-sync`) but
written, tested, and maintained by us. **Status: implemented (`v0.1.0`).**

1. **Scaffold the package** under `.specify/extensions/umbrella-fanout/`
   (extension manifest + namespaced commands, so `specify self upgrade` never
   touches our files). ✅
2. **Hooks**:
   - `after_plan` → discover affected modules from the plan's **Affected
     Repositories** list.
   - `after_tasks` → create the matching branch in each affected module
     (`/speckit.umbrella-fanout.fanout`).
   Registered in `.specify/extensions.yml` (both optional, priority 10). ✅
3. **Config** in `.specify/init-options.json` (`umbrella_fanout`: `switch`,
   `skip_branches`, `exclude`) with `type: submodule` defaults. ✅
4. **Safety**: `--dry-run`, best-effort switching (never clobber a dirty
   working tree — untracked files included), idempotent re-runs. Implemented in
   `.specify/scripts/bash/fanout.sh`. ✅
5. **Verify**: run it on a throwaway feature; compare against the manual
   commands of section 4; leave section 4 as the documented fallback.
   ✅ (script self-tested; section 4 remains the fallback).

The agent-facing command is `/speckit.umbrella-fanout.fanout` (wraps
`fanout.sh`); it runs after plan/tasks via the hooks, or manually at any time.
To reinstall after editing the extension source, run
`specify extension add .specify/extensions/umbrella-fanout --dev` from a temp
location — but the committed copy in `.specify/extensions/umbrella-fanout/` is
the canonical source, and section 4 is always the fallback.

---

## 5. Spec change / pointer update

A spec changes through `CONTRIBUTING.md`: PR in the specs repo → review and
approval → merge → tag `spec-vX.Y.Z` + `CHANGELOG.md` entry. Then each module
decides independently when to move:

```sh
git -C modulos/<module>/specs fetch origin
git -C modulos/<module>/specs checkout spec-v<X>.<Y>.<Z>
cd modulos/<module> && git add specs
cd ../.. && git commit -m "chore: pin specs to spec-v<X>.<Y>.<Z>"
```

A module may stay on an older tag while it finishes current work. It blocks no
one.

## 6. Constitution cascade and discovery

The global constitution lives **once** in the specs repo
(`.specify/memory/constitution.md`). Every repo sees the same file because every
repo mounts the same specs submodule — backend, bff and frontend all read the
identical global constitution at the same pinned tag.

When working inside a module, read in this order:

1. Global: `modulos/<module>/specs/.specify/memory/constitution.md` (from the
   specs submodule — same content for every repo).
2. Local overrides (if the file exists):
   `modulos/<module>/.specify/memory/constitution.md`.

The local file only adds targeted overrides (e.g. the module language's test
framework). It never re-defines global principles.

Discovery (`.agent-context`) lives per repo:

- `modulos/<module>/.specify/memory/.agent-context` — inside the module repo.
  It points at the specs folder/task file that applies to that module, e.g.
  `specs/specs/NNN-checkout-flow/tasks/frontend.md`.
- It is what `/speckit.implement` reads to know which task file the repo owns.
- The umbrella itself does not need one; it only orchestrates.

## 7. Flexibility

- A module may pin any spec tag; it chooses when to move forward.
- Local constitutions and task files are optional per module.
- Modules are added/removed by repeating step 4 of section 2; nothing else
  changes.
- If manual fan-out becomes the bottleneck, we automate with our own extension
  (section 4.1) — never a third-party one. Community tools in
  `docs/multi-repo-speckit-verification.md` are research reference only.
