---
description: Verify the implementation — tasks marked done, checklists green, and the project's own tests/build passing (per module and for the feature).
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. **Locate the verification context**:
   - Run `.specify/scripts/bash/check-prerequisites.sh --paths-only` from the repo
     root and parse `REPO_ROOT`, `BRANCH`, `FEATURE_DIR`, `FEATURE_SPEC`,
     `IMPL_PLAN`, `TASKS`.
   - In a module (`modulos/<module>`), the same command resolves the module's own
     feature context (its `.specify/`); in the specs repo it resolves the feature
     docs. If no feature context exists, verify what is present and say so.

2. **Verify tasks.md completion**:
   - If `TASKS` exists: count `- [ ]` (open) vs `- [X]`/`- [x]` (done).
   - All open tasks must be done for PASS. Report the table (done/total per
     phase). Open tasks → FAIL with the list, unless the user says to proceed.

3. **Verify checklists** (if `FEATURE_DIR/checklists/` exists):
   - For each checklist file, count total vs completed `- [X]`/`- [x]`.
   - `| Checklist | Total | Completed | Incomplete | Status |`.
   - Any incomplete checklist → FAIL, list the incomplete items.

4. **Verify the implementation runs** (per module):
   - Detect the module's build/test tooling from `plan.md` tech stack or the
     repo itself (`pom.xml` → `./mvnw test`, `package.json` → `npm test`,
     `pyproject.toml` → `pytest`, etc.).
   - Run the test command in the module. Tests fail → FAIL.
   - If contracts/ exists with tests, run those too.

5. **Verify against the spec**:
   - Re-read the feature's `spec.md` user stories and `contracts/`; confirm the
     implemented behavior matches (endpoints, entities, acceptance criteria).
   - Note any drift explicitly.

6. **Verdict**: PASS (all of the above green), FAIL (report every failing item
   with the exact command/output that failed), or PARTIAL (e.g. tasks done but
   no test command found — say what was not verified).

## Completion Report

Report per area: tasks, checklists, build/tests, spec/contract fit. Include the
exact commands run and their results so failures are reproducible. When run per
module and again for the feature, both verdicts together close lifecycle step 7
of `docs/WORKFLOW.md`.

## Done When

- [ ] tasks.md completion counted and reported
- [ ] Checklists (if any) counted and reported
- [ ] Build/test command detected and run in the module
- [ ] Verdict issued: PASS / FAIL / PARTIAL with the supporting evidence
