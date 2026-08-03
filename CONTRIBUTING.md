# Spec change process

Las specs se versionan y se comparten entre módulos. Cambiar una spec aprobada
es siempre un acto explícito, revisado y versionado — nunca una actualización
automática.

## Pasos

1. **Abre un PR en el repo de specs.** Nunca edites `main` directamente.
2. **Review y aprobación.** Los cambios requieren review y aprobación, exigidos
   por la branch protection del repo de specs.
3. **Al mergear:** crea un tag semver nuevo (`spec-vMAJOR.MINOR.PATCH`) y añade
   una entrada al `CHANGELOG.md` del repo de specs.
4. **Cada módulo actualiza su puntero explícitamente, cuando lo decide.** Dentro
   del módulo, pineas el submodulo de specs al tag nuevo:

   ```sh
   git -C modulos/<module>/specs fetch origin
   git -C modulos/<module>/specs checkout spec-v<MAJOR>.<MINOR>.<PATCH>
   git add modulos/<module>/specs
   git commit -m "chore: pin specs to spec-v<MAJOR>.<MINOR>.<PATCH>"
   ```

   Nunca actualices el puntero de specs de un módulo automáticamente como parte
   de otro cambio.

5. **Los módulos pueden quedarse atrás.** Un módulo puede permanecer en una
   versión anterior de specs mientras termina su implementación actual. Eso no
   bloquea a nadie.
