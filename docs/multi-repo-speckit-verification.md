# Multi-repo + Spec Kit: Industry Practice — Verification Brief

> Purpose: this document summarizes what an AI agent found while researching how
> Spec Kit (speckit) is used in the industry for multi-module / multi-repo
> projects (git submodules and nested repos). It is meant to be handed to a
> second AI to **fact-check every claim** against the cited sources.
>
> Every claim has a source URL and a verification status. Items marked
> `NEEDS VERIFICATION` were inferred or not fully confirmed and must be checked.

---

## 1. Executive summary

The pattern described in `docs/prompt-umbrella-speckit.md` — a **dedicated specs
repository** consumed by implementation repos **as pinned git submodules**, with a
**cascading constitution** (global + local overrides) and **per-module
`.agent-context`** — matches the documented multi-repo pattern used with Spec
Kit in the industry. It is not an exotic design; it is the recommended way to do
multi-repo with speckit.

Two caveats surfaced by research:

1. speckit core assumes a **single git repository** per project. It only creates
   feature branches in the root repo; it does not fan branches out to
   submodules/nested repos out of the box.
2. speckit has **no built-in constitution inheritance**. A shared/cascading
   constitution must be wired manually — which is exactly what the umbrella doc
   does.

Community tooling exists to close gap #1 (preset and hook-based extension; see
claims 5–7).

---

## 2. Claims

### Claim 1 — Spec Kit projects are directory-scoped

- **Claim:** A Spec Kit project is the directory that contains `.specify/`. A
  monorepo can hold several independent Spec Kit projects under one repo root,
  each with its own `.specify/`, `specs/`, constitution, and feature numbering.
- **Status:** VERIFIED via search results from the official spec-kit repo
  documentation.
- **Source:** https://github.com/github/spec-kit/blob/bba473c2/docs/guides/monorepo.md
  (guide merged via PR #3084: https://github.com/github/spec-kit/pull/3084)

### Claim 2 — `SPECIFY_INIT_DIR` targets a member project from the repo root

- **Claim:** `SPECIFY_INIT_DIR` selects the member project (the directory
  containing its `.specify/`). Relative paths resolve against the current
  directory. If the path does not exist or has no `.specify/`, the command
  **errors and does not fall back**. `SPECIFY_INIT_DIR` and
  `SPECIFY_FEATURE_DIRECTORY` compose (project + feature selection).
- **Status:** VERIFIED via search results from official docs (the monorepo guide
  and the reference doc for environment variables).
- **Source:** https://github.com/github/spec-kit/blob/bba473c2/docs/guides/monorepo.md
  and `docs/reference/core.md#environment-variables` in the same repo.

### Claim 3 — Git operations run in the containing work tree (shared branches)

- **Claim:** In a monorepo with one root git repo, feature branch creation
  happens in the shared root repo even when a member project is targeted. Spec
  dirs stay under the selected member project; the branch namespace is shared.
  For isolated per-project branch namespaces you must init git per member
  project.
- **Status:** VERIFIED via search results from the official guide.
- **Source:** https://github.com/github/spec-kit/blob/bba473c2/docs/guides/monorepo.md

### Claim 4 — No built-in constitution inheritance

- **Claim:** Spec Kit does not provide a built-in base/inheritance mechanism for
  constitutions. Each project's `/speckit.constitution` edits its own local
  `.specify/memory/constitution.md`. If you want one constitution to reference
  shared rules elsewhere (a cascade), you must maintain that wiring yourself.
- **Status:** VERIFIED via search results from the official guide.
- **Source:** https://github.com/github/spec-kit/blob/bba473c2/docs/guides/monorepo.md

### Claim 5 — speckit core only branches the root repo (the gap)

- **Claim:** When starting a feature, speckit creates the feature branch only in
  the root repository (where `.specify/` lives). Nested independent repos and
  git submodules stay on their previous branch/commit, creating a workflow
  mismatch in multi-module projects.
- **Status:** VERIFIED — reported as issues on the official repo.
- **Sources:**
  - Submodules: https://github.com/github/spec-kit/issues/1050
  - Independent nested repos: https://github.com/github/spec-kit/issues/2120
  - Monorepo branch-namespace note: https://github.com/github/spec-kit/issues/3081

### Claim 6 — Preset: `spec-kit-preset-multi-repo-branching`

- **Claim:** A community preset coordinates feature branches across
  submodules/independent repos. It works by **overriding** the core
  `speckit.plan` and `speckit.tasks` commands (replace strategy at install
  time). It discovers child repos during `plan` and generates branch-creation
  tasks during `tasks`. Because it replaces core command files, every
  `specify self upgrade` either reverts the customization or re-overwrites the
  new core version → manual merge each time.
- **Status:** VERIFIED via the preset repo README and the extension repo's
  comparison.
- **Sources:**
  - https://github.com/sakitA/spec-kit-preset-multi-repo-branching
  - https://github.com/github/spec-kit/pull/2139 (adds it to the community catalog)
- **Config** (per its README): `multi_repo_branching` block in
  `.specify/init-options.json` — `type` (`independent` | `submodule` | `auto`,
  default `auto`), `scan_depth` (1–10, default 2).

### Claim 7 — Extension: `spec-kit-multi-repo-sync` (hook-based, upgrade-safe)

- **Claim:** A community extension achieves the same branch fan-out through Spec
  Kit **hooks** (`after_plan` and `after_tasks`) instead of overriding core
  commands. Commands are namespaced (`/speckit.multi-repo-sync.analyze`,
  `/speckit.multi-repo-sync.sync`, `/speckit.multi-repo-sync.status`). It does
  not touch core files, so it survives `specify self upgrade` and inherits core
  improvements.
- **Status:** VERIFIED via the extension repo README.
- **Source:** https://github.com/fyloss/spec-kit-multi-repo-sync
- **Config keys:** `type` (`auto` default | `independent` | `submodule`),
  `scan_depth` (default 2), `switch` (default `true`), `skip_branches`
  (default `["main","master"]`), `exclude` (default `[]`). Read from
  `multi_repo_branching` in `.specify/init-options.json` or extension-local
  config.
- **Caveat:** requires a spec-kit core version where the `after_plan` hook is
  wired into command templates. On older cores `after_plan` may be silent
  (though `after_tasks` works).

### Claim 8 — The "dedicated specs repo + submodules" multi-repo pattern

- **Claim:** A published industry walkthrough (Jan 2026) describes using Spec
  Kit across three repos: a dedicated `*-specs` repo (source of truth:
  requirements, API contracts, plans, shared constitution) consumed by
  implementation repos as **pinned git submodules**. Each implementation repo
  adds `.specify/memory/.agent-context` (which task file it owns) and an
  optional local `constitution.md` with overrides. Global rules come from
  `specs/.specify/memory/constitution.md`; local rules from the repo's own
  `.specify/memory/constitution.md`. Spec updates are conscious: submodules are
  locked to commits, so breaking changes do not propagate accidentally.
- **Status:** VERIFIED — matches the umbrella doc's design and is consistent
  with claims 1–7.
- **Source:** https://medium.com/@parthsehgal16/github-copilot-speckit-for-multi-repository-projects-5da7bc181531

---

## 3. Local CLI facts (verified on this machine)

Verified by running the CLI directly (`specify` v0.14.2):

| Fact | Evidence |
|------|----------|
| `specify --version` → `specify 0.14.2` | ran locally |
| CLI subcommands: `init`, `check`, `version`, `self`, `extension`, `integration`, `preset`, `bundle`, `workflow` | `specify --help` |
| `specify init` scaffolds from bundled assets (no network), checks tools, lets you choose a coding-agent integration, installs templates/workflow/shared infra, sets up agent commands and presets | `specify init --help` |
| `specify init` supports `--here`, `--force`, `--integration <name>` (claude, codex, generic, gemini, copilot, …), `--ignore-agent-tools` | `specify init --help` |
| `opencode` is detected as an available integration | `specify check` → "opencode (available)" |
| `specify check` did NOT list a dedicated "constitution generator" — the doc's `/speckit.constitution` is a speckit *command* (installed via `specify init`), not a standalone CLI binary | `specify check` |
| `specify extension|preset|workflow|bundle` exist with `search/add/list/info` commands — catalogs are the install path for the community tooling in claims 6–7 | `specify extension --help`, etc. |

---

## 4. Claims that NEED manual verification

These were not fully confirmed and should be checked by the verifying AI or
manually:

1. **Exact install command for the extension/preset.** Expected path:
   `specify extension search multi-repo-sync` → `specify extension add <id-or-URL>`
   (and analogously `specify preset add`). Confirm the exact catalog ID/name and
   URL form before running.
2. **`--integration opencode`** — confirm opencode appears in the CLI's
   integration list once inside an initialized project
   (`specify integration list` requires a project with `.specify/`).
3. **Full content of the official monorepo guide** — the claim summary above is
   based on search-result highlights; fetch and read
   `docs/guides/monorepo.md` in full to confirm exact wording, especially:
   - the no-inheritance statement,
   - the `SPECIFY_INIT_DIR` error-no-fallback behavior,
   - the branch-namespace note.
4. **`after_plan` hook wiring in current core** — the extension's README warns
   older cores may not wire `after_plan` even when `after_tasks` is wired.
   Verify against the installed core version.
5. **Behavior of `specify init` non-interactive default** — help text says it
   defaults to Copilot in non-interactive sessions; confirm the flag to force
   `opencode` non-interactively (`--integration opencode`).
6. **Whether `specify workflow` (the CLI's own workflow engine) is the
   recommended mechanism** vs. the preset/extension hooks — the workflow engine
   exists as a CLI subsystem but the research surfaced the hook-based extension
   as the primary community answer for multi-repo branching. Confirm which is
   canonical for this use case.

---

## 5. Sources (all URLs)

- Official spec-kit repo (docs, guides): https://github.com/github/spec-kit
  - Monorepo guide: https://github.com/github/spec-kit/blob/bba473c2/docs/guides/monorepo.md
  - Monorepo guide PR: https://github.com/github/spec-kit/pull/3084
  - Issue #1050 (submodules): https://github.com/github/spec-kit/issues/1050
  - Issue #2120 (nested repos): https://github.com/github/spec-kit/issues/2120
  - Issue #3081 (monorepo branch namespace): https://github.com/github/spec-kit/issues/3081
  - PR #2139 (preset to catalog): https://github.com/github/spec-kit/pull/2139
- Preset (sakitA): https://github.com/sakitA/spec-kit-preset-multi-repo-branching
- Extension (fyloss): https://github.com/fyloss/spec-kit-multi-repo-sync
- Industry walkthrough (TaskMaster, Jan 2026):
  https://medium.com/@parthsehgal16/github-copilot-speckit-for-multi-repository-projects-5da7bc181531

---

## 6. What this project needs next (context for the verifier)

- The umbrella repo: https://github.com/gerardo-lopez-dev/umbrella
  (`AGENTS.md` and `CONTRIBUTING.md` already encode the binding rules;
  `docs/WORKFLOW.md` defines the end-to-end workflow; the bootstrap from
  `docs/prompt-umbrella-speckit.md` has NOT been executed).
- Decided direction (per user): keep the umbrella pattern; document the
  workflow; **do NOT install the `multi-repo-sync` extension** — branch
  fan-out across modules is manual with plain `git` by default
  (see `docs/WORKFLOW.md` §4), and automation, when built, **must be our own
  in-house extension** (§4.1) — a commitment, never a third-party dependency.
  The extension/preset claims above are kept as research reference only;
  execution of the bootstrap is deferred.
