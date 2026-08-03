---
description: Fan out the current feature branch to the affected module submodules (manual git, in-house).
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. **Resolve config**: read the `umbrella_fanout` block in `.specify/init-options.json`
   (`type`, `switch`, `skip_branches`, `exclude`). Absent keys default to
   `submodule`, `true`, `["main","master"]`, `[]`.

2. **Resolve the feature branch**:
   - `--branch <name>` from user input wins.
   - Else the current branch of `modulos/specs-lib`
     (`git -C modulos/specs-lib symbolic-ref --short HEAD`).
   - Else STOP: no branch to fan out.

3. **Resolve the affected modules** (fan out ONLY what the plan marks as affected):
   - Repeated `-m <module>` from user input wins.
   - Else read the **Affected Repositories** list from the feature's `plan.md`
     (under the specs submodule, e.g. `modulos/specs-lib/specs/NNN-name/plan.md`).
   - If neither yields modules, STOP: fan-out to every module would pollute repos
     the feature does not touch.

4. **Run the fan-out** with the resolved values:

   ```sh
   .specify/scripts/bash/fanout.sh \
     --branch <feature-branch> \
     -m <module-1> [-m <module-N>...] \
     [--dry-run]
   ```

   Always recommend a `--dry-run` first so the user sees exactly what changes.

5. **Report**: for each module, the resulting action (`created`, `exists`, `skipped`,
   `already on branch`) or, with `--dry-run`, the command that would run. Never
   force a switch onto a dirty working tree; skip and report it (best-effort).

## Completion Report

Summarize: branch, modules fanned out, per-module result, and anything left to
the user (e.g. a module skipped because it was dirty). Manual git (section 4 of
`docs/WORKFLOW.md`) remains the fallback if this extension misbehaves.

## Done When

- [ ] Feature branch created in the specs reference (`modulos/specs-lib`) and in
      every affected module submodule, or an explicit reason recorded per module
- [ ] Nothing was clobbered: dirty trees were skipped, not switched
- [ ] Summary reported to the user
