# umbrella

Orchestrating repo of a multi-repo project built with Spec Kit (speckit). It
does not hold implementation code: it pins shared specs and the implementation
modules (each in its own repo) as git submodules.

## Structure

```
. (this repo, umbrella)
├── .specify/                          Spec Kit for the whole project
│   └── memory/constitution.md         GLOBAL constitution
├── modulos/
│   ├── specs-lib/                     submodule → specs repo, pinned to a tag
│   └── <module-1>/                    submodule → implementation repo
│       ├── specs/                     submodule → same specs repo, same tag
│       └── .specify/memory/
│           ├── .agent-context
│           └── constitution.md        LOCAL overrides (optional)
├── CONTRIBUTING.md                    spec change process
└── README.md
```

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
