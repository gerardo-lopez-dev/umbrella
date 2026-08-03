---
description: Run any umbrella workflow phase against a target repo (specs or a module) from the umbrella root. Never cd.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

Expected shape: `/speckit.umbrella.run <target> <phase> [args]`

- `<target>` — where to work: `specs` | `umbrella` | a module name (e.g. `microservice-template`).
- `<phase>` — what to run: `specify` | `plan` | `tasks` | `implement` | `verify` | `fanout`.
- `[args]` — extra arguments passed through to the underlying phase. `specify`
  takes an optional feature name; if omitted, you derive it (see below).

## Operating model (binding)

The umbrella is the **only** session workspace. Never `cd` out of the umbrella
root; never start a new session inside a submodule. All paths below are
umbrella-relative; submodule git operations use `git -C`; GitHub operations use
`gh` with the repo resolved from the submodule's remote.

Target map:

| Target | Root on disk | Speckit context |
|--------|--------------|-----------------|
| `specs` | `modulos/specs-lib` | `SPECIFY_FEATURE_DIRECTORY=modulos/specs-lib/specs/NNN-name` |
| `umbrella` | `.` | umbrella's `.specify/feature.json` |
| `<module>` | `modulos/<module>` | module-mounted specs at `modulos/<module>/specs/specs/NNN-name` |

## Outline

1. **Resolve the target** with the table above. Unknown target → STOP and ask.
   The feature dir `NNN-name` comes from `.specify/feature.json`, from
   `SPECIFY_FEATURE_DIRECTORY`, or from the latest feature under
   `modulos/specs-lib/specs/` — resolve it once and reuse it.

2. **Dispatch the phase** (all commands run from the umbrella root):

   - **`specify [<feature>]`** → create the feature in the specs repo. Feature
     name follows the `NNN-slug` convention (`BRANCHING.md`): `NNN` from the
     ROADMAP post number, `slug` the kebab-case title. If not given, derive it
     from the ROADMAP item the user points at (e.g. "Post 01" →
     `001-spring-profiles`) and report it to the user. Set
     `SPECIFY_FEATURE_DIRECTORY=modulos/specs-lib/specs/<feature>` so the
     umbrella's speckit scripts resolve the right feature dir; follow the
     `/speckit.specify` command for the rest.
   - **`plan` / `tasks`** → run against the specs repo using the same
     `SPECIFY_FEATURE_DIRECTORY`. Record **Affected Repositories** in `plan.md`
     (this drives the fan-out).
   - **`fanout`** → delegate to `/speckit.umbrella-fanout.fanout` (base `main`
     per config, only affected modules, `--dry-run` first).
   - **`implement`** → work in `<module>`:
     1. Read `modulos/<module>/.specify/memory/.agent-context` (which specs folder
        applies, constitution cascade order).
     2. Read the module task file at
        `modulos/<module>/specs/specs/NNN-name/tasks/<module>.md`.
     3. Read the constitution cascade: global first
        (`modulos/<module>/specs/.specify/memory/constitution.md`), then local
        (`modulos/<module>/.specify/memory/constitution.md`) if present.
     4. Implement the module tasks by writing/editing files under
        `modulos/<module>/`. Run builds/tests as subprocesses with the module as
        working dir (e.g. `./mvnw test` inside `modulos/<module>`).
   - **`verify`** → module-level: run `modulos/<module>` build/tests, check the
     module task file; feature-level: check `tasks.md` and `checklists/` in the
     specs feature dir (via `SPECIFY_FEATURE_DIRECTORY` if needed). Report
     PASS/FAIL/PARTIAL.

3. **Never `cd`.** If a speckit helper must resolve the target's own project
   root (a target with its own `.specify/feature.json`), set
   `SPECIFY_INIT_DIR=modulos/<target>` — otherwise rely on
   `SPECIFY_FEATURE_DIRECTORY` + umbrella-relative paths.

## Completion Report

Report: target used, phase run, feature dir, files changed (with
umbrella-relative paths), and anything the user must do next (e.g. PRs, tag).

## Done When

- [ ] Phase ran against the requested target with files under `modulos/<target>` (or specs) — no `cd`, no new session
- [ ] Feature dir `NNN-name` resolved and reported consistently across steps
- [ ] Module phases respected `.agent-context` and the constitution cascade
- [ ] Summary reported to the user
