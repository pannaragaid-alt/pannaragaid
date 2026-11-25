# V17 Global Growth Engine

Version: **0.7.0**  
Current hardening baseline: **P1 Operational Hardened**

## Source archive

The validated source package is [V17_GLOBAL_GROWTH_ENGINE_0.7.0_P1_OPERATIONAL_HARDENED.zip](./V17_GLOBAL_GROWTH_ENGINE_0.7.0_P1_OPERATIONAL_HARDENED.zip).

The archive is SHA-256 pinned in the GitHub Actions workflow. The workflow downloads the exact archive, verifies its digest, installs the project and test/security dependencies, runs the complete test suite on Python 3.11 and 3.12, compiles the source, builds wheels, and runs Ruff, Bandit, pip-audit, and Semgrep.

## Validation

- Trigger: push to `main`, pull request targeting `main`, or manual dispatch.
- Workflow: [V17 P1 Operational Validation](.github/workflows/v17-p0-validation.yml).
- CI success is a code-validation result; it is **not** production-readiness evidence.

## Operational acceptance gate

P1 remains open until the following are executed in a controlled staging environment and the evidence is recorded:

1. Backup and restore drill, including measured RPO/RTO and application-level integrity checks.
2. Process supervision, graceful shutdown, crash recovery, worker restart, and lease recovery tests.
3. Centralized structured logs, metrics, dashboards, and tested alert delivery.
4. Authentication and authorization/RBAC enforcement, including negative tests and confirmation that anonymous public access is blocked.
5. Provider integration, concurrency/load/soak tests, rate-limit handling, and multi-user isolation.
6. Staging rollback rehearsal, including data consistency and recovery verification.
7. Repository governance: protected `main`, required PR approval, all seven required CI checks, and force-push/deletion prevention.

See [P1 Operational Acceptance](docs/P1_OPERATIONAL_ACCEPTANCE.md) for evidence requirements and exit criteria, and [Repository Governance](docs/operations/REPOSITORY_GOVERNANCE.md) for the administrator runbook and verification helper.

## Release policy

This repository does not publish packages to PyPI or any other package registry. Build artifacts are validation outputs only. No public deployment is authorized by a green CI run.
