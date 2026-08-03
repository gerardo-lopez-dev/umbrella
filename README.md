# umbrella

Orchestrating repo of a multi-repo project built with Spec Kit (speckit). It
does not hold implementation code: it pins shared specs and the implementation
modules (each in its own repo) as git submodules.

## Structure

```
. (this repo, umbrella)
├── .specify/                          Spec Kit for the whole project
│   ├── memory/constitution.md         GLOBAL constitution
│   ├── init-options.json              speckit config (feature numbering, fan-out)
│   ├── extensions.yml                 hooks → umbrella-fanout extension
│   └── scripts/bash/                  fanout.sh, module-bootstrap.sh + self-checks
├── modulos/
│   ├── specs-lib/                     submodule → specs repo, pinned to a tag
│   └── <module>/                      submodule → implementation repo
│       ├── specs/                     submodule → same specs repo, same tag
│       └── .specify/memory/
│           ├── .agent-context
│           └── constitution.md        LOCAL overrides (optional)
├── AGENTS.md                          binding rules for agents
├── BRANCHING.md                       GitHub Flow convention + branch protection
├── CONTRIBUTING.md                    spec change process
├── docs/
│   ├── WORKFLOW.md                    end-to-end workflow
│   ├── ROADMAP.md                     project roadmap
│   └── flujo-ejemplo-post01.html      example feature walkthrough (interactive)
└── .opencode/commands/                /speckit.* commands (incl. umbrella.run)
```

## Operating model — everything from the umbrella root

The umbrella is the **only** session workspace. Never `cd` into a submodule or
start a session inside one: files use umbrella-relative paths
(`modulos/...`), submodule git uses `git -C modulos/<m>`, GitHub uses `gh` with
the repo resolved from the submodule's remote, and speckit context resolves via
`SPECIFY_FEATURE_DIRECTORY`. Single entry point for every phase:

```
/speckit.umbrella.run <target> <phase>
```

| Target | Root on disk | Phases |
|--------|--------------|--------|
| `specs` | `modulos/specs-lib` | `specify`, `plan`, `tasks` |
| `umbrella` | `.` | `fanout` |
| `<module>` | `modulos/<module>` | `implement`, `verify` |

Feature/branch names follow `NNN-slug` (`BRANCHING.md`); the assistant derives
them from the ROADMAP post — they are not typed.

## Constitution cascade

Read order for anyone implementing inside a module:

1. **Global first**: `modulos/<module>/specs/.specify/memory/constitution.md`
   (the specs submodule, same tagged version for every module).
2. **Local overrides second** (if present): `modulos/<module>/.specify/memory/constitution.md`.
   Local files only add targeted overrides; they never contradict the global one.

Check `modulos/<module>/.specify/memory/.agent-context` to know which folder
under `specs/specs/` applies to that module.

## Submodule pinning

Every `specs` submodule is pinned to a fixed tag (never `main`). Updating a
module's spec is always an explicit act. See `CONTRIBUTING.md` for the
spec-change flow.

## Verified state

- Submodules pinned to `spec-v1.0.0` (`modulos/specs-lib` and
  `modulos/microservice-template/specs`, same commit).
- `microservice-template` on `main`; its `main` is branch-protected (1 review +
  required CI `build`, strict, admins enforced, no force-push/deletions).
- `specs` repo `main` is branch-protected too (1 review, admins enforced, no
  force-push/deletions — no CI checks; specs has none).
- Self-checks PASS: `bash .specify/scripts/bash/{fanout-test,module-bootstrap-test,context-test}.sh`.
