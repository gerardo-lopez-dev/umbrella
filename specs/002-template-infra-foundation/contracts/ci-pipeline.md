# CI/CD Pipeline

## GitHub Actions Workflow

**File**: `.github/workflows/ci.yml`

**Trigger**: Push to `main`, PR to `main`

### Stages

| Stage | Command | Failure Action |
|-------|---------|---------------|
| Lint | `mvn spotless:check` | Fail build |
| Test | `mvn verify` (includes jacoco report) | Fail build |
| Build | `mvn package -DskipTests` | Fail build |
| Coverage | JaCoCo report upload | Warning only |
| Docker | `docker/build-push-action` | Fail build |

### Dependabot

**File**: `.github/dependabot.yml`

| Ecosystem | Schedule | Assignees |
|-----------|----------|-----------|
| Maven | Weekly | — |
| GitHub Actions | Weekly | — |
