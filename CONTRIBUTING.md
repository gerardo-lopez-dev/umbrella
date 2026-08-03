# Spec change process

Specs are versioned and shared across modules. Changing an approved spec is
always an explicit, reviewed act — never an automatic update.

## Steps

1. **Open a PR in the specs repo.** Never edit `main` directly.
2. **Review and approval.** Changes require review and approval, enforced by
   branch protection on the specs repo.
3. **On merge:** create a new semver tag (`spec-vMAJOR.MINOR.PATCH`) and add an
   entry to the specs repo `CHANGELOG.md`.
4. **Each module updates its pointer explicitly, when it decides to.** Inside
   the module, pin the specs submodule to the new tag:

   ```sh
   cd modulos/<module>/specs
   git fetch origin
   git checkout spec-v<MAJOR>.<MINOR>.<PATCH>
   cd ../..
   git add specs
   git commit -m "chore: pin specs to spec-v<MAJOR>.<MINOR>.<PATCH>"
   ```

   Never update a module's specs pointer automatically as part of another
   change.

5. **Modules may lag behind.** A module can stay on an older spec version while
   it finishes current implementation work. This blocks no one.
