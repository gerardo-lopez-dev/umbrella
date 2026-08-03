# AGENTS.md

## What this repo is

`umbrella` is the orchestrating repo of a multi-repo project built with Spec Kit
(speckit). It does not hold implementation code: it pins shared specs and the
implementation modules (each in its own repo) as git submodules.

The target structure (being assembled following `docs/prompt-umbrella-speckit.md`):

```
. (this repo, umbrella)
├── .specify/                          Spec Kit for the whole project
│   └── memory/constitution.md         GLOBAL constitution
├── modulos/
│   ├── specs-lib/                     submodule → specs repo, pinned to a tag
│   ├── <module-1>/                    submodule → implementation repo
│   │   ├── specs/                     submodule → same specs repo, same tag
│   │   └── .specify/memory/
│   │       ├── .agent-context
│   │       └── constitution.md        LOCAL overrides (optional)
│   └── <module-N>/ ...
├── CONTRIBUTING.md                    spec change process
└── README.md
```

## Binding rules

These are non-negotiable. Do not break them.

1. **Specs live in a separate repo**, versioned with semver tags
   `spec-vMAJOR.MINOR.PATCH`.
2. **No module follows `main` of the specs repo.** Every submodule is pinned to a
   fixed commit/tag. Updating a module's spec is ALWAYS an explicit act, never
   automatic.
3. **Constitution is read in cascade.** When implementing inside a module, read
   first the global one (`modulos/<module>/specs/.specify/memory/constitution.md`),
   then the module's local one (`modulos/<module>/.specify/memory/constitution.md`)
   if it exists — the local file only adds targeted overrides.
4. **Spec changes always go through the process in `CONTRIBUTING.md`**:
   PR in the specs repo (never edit `main` directly) → review and approval →
   new tag + `CHANGELOG.md` entry → each module explicitly updates its pointer
   when it decides to. A module may stay on an older version while it finishes
   current work; it blocks no one.

## Working in a module

- Before implementing in `modulos/<module>`, read the constitution cascade
  (global first, then local overrides).
- Check `modulos/<module>/.specify/memory/.agent-context` to know which folder
  under `specs/specs/` applies to that module.
- Never move a specs submodule to a new tag on your own. Propose the spec
  change through the specs repo PR flow first.

## References

- `CONTRIBUTING.md` — spec change process.
- `BRANCHING.md` — branching convention (GitHub Flow, all repos).
- `docs/WORKFLOW.md` — end-to-end workflow (bootstrap, feature lifecycle, manual
  branch fan-out across modules).
- `docs/prompt-umbrella-speckit.md` — bootstrap steps to assemble this structure.
- `docs/ROADMAP.md` — project roadmap.
