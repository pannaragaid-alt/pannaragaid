# P1 Operational Acceptance Runbook

Status: **OPEN — execution evidence required**  
Scope: V17 Global Growth Engine 0.7.0 P1  
Rule: Do not mark P1 accepted or proceed to P2 until every gate below is passed and evidence is retained.

This document defines operational acceptance. It does not claim that any drill has already been performed.

## 1. Backup and restore

### Required implementation
- Define the authoritative data set: SQLite database, WAL/SHM handling, configuration, and required encrypted secret material.
- Use a SQLite-consistent backup mechanism (SQLite backup API or a verified checkpoint plus atomic snapshot); do not copy a live database file without a consistency strategy.
- Encrypt backups at rest and in transit; keep encryption keys separate from backup storage.
- Store at least one copy outside the primary host/account failure domain.
- Enforce retention, access control, integrity checks, and deletion policy.
- Record backup completion/failure and alert on missed schedules.

### Drill and pass criteria
- Restore into a clean, isolated staging instance using only the documented recovery procedure.
- Verify SQLite integrity and foreign-key checks after restore.
- Verify application-level invariants: schema version, representative records, job state/leases, report readability, and application startup/doctor checks.
- Measure and record actual RPO and RTO; both must meet explicitly approved service objectives.
- Demonstrate recovery from a corrupt or incomplete latest backup by selecting a known-good prior backup.
- Retain timestamped command output, checksums, restore logs, and reviewer sign-off.

## 2. Runtime supervision and recovery

### Required implementation
- Run as a dedicated non-root OS identity with least-privilege filesystem permissions.
- Use a process supervisor (for example systemd or an equivalent orchestrator) with bounded restart policy, startup ordering, stop timeout, and resource limits.
- Separate web/API and worker lifecycle where the architecture requires it.
- Implement readiness/liveness checks that validate dependencies rather than merely checking that a PID exists.
- Ensure graceful shutdown stops accepting new work, persists checkpoints, and releases or safely expires leases.
- Document configuration and secret injection without placing secrets in command-line arguments or logs.

### Drill and pass criteria
- Start, stop, restart, and upgrade through the supervisor.
- Kill the process during an active job; verify lease expiry/reclaim and idempotent recovery without duplicate side effects.
- Restart during a database write and verify database integrity.
- Verify repeated crashes are rate-limited and produce an actionable alert rather than an infinite restart loop.
- Verify the service remains unavailable to unauthenticated clients during restart/recovery.

## 3. Logs, metrics, dashboards, and alerting

### Required implementation
- Emit structured logs with UTC timestamps, severity, service/component, correlation/request/job IDs, and sanitized error context.
- Redact credentials, OAuth tokens, authorization headers, personal data, and provider payloads before logs leave the process.
- Centralize logs with access control, retention, and tamper-aware storage.
- Export metrics for request/job throughput, error rates, latency, queue depth/age, retries, lease expiry, worker saturation, database/WAL size, disk space, and process health.
- Define service-level objectives and actionable alert thresholds.

### Drill and pass criteria
- Demonstrate log search across one request and its downstream job.
- Trigger and acknowledge test alerts for process failure, queue backlog, repeated provider errors, disk pressure, and missed backup.
- Verify alert routing, deduplication, escalation, and recovery notifications.
- Confirm no secrets or sensitive provider payloads appear in logs, traces, or metric labels.

## 4. Authentication, authorization, and public exposure

### Required implementation
- Keep public access disabled until an approved authentication boundary is configured.
- Enforce OIDC/SSO or an equivalent centrally managed identity provider at the application boundary or trusted reverse proxy.
- Define least-privilege roles for administrator, operator, analyst, and read-only access as applicable.
- Enforce authorization server-side for every protected operation, including exports, configuration, job control, and secret references.
- Apply session security, CSRF protection where cookie-based sessions are used, secure cookies, TLS, rate limits, and audit events.
- Keep provider credentials in a secret manager; do not expose secrets to the browser or ordinary users.

### Drill and pass criteria
- Verify anonymous requests are denied at the network edge and application layer.
- Run positive and negative role matrix tests for every sensitive operation.
- Verify privilege escalation, IDOR, CSRF, session fixation/replay, and direct-object access tests fail safely.
- Verify account revocation and credential rotation take effect within the approved window.
- Confirm audit records identify actor, action, target, timestamp, and outcome without recording secret values.

## 5. Staging integration, load, and resilience

### Required implementation
- Provision an isolated staging environment with production-equivalent topology and no production secrets/data.
- Use provider sandbox credentials where available; otherwise use explicitly approved test accounts and strict quotas.
- Document dependency versions, resource sizing, configuration, network egress allowlists, and secret ownership.
- Define workload profiles, concurrency limits, expected throughput, latency/error objectives, and maximum resource budgets.

### Drill and pass criteria
- Exercise each configured provider end-to-end, including authentication expiry, invalid credentials, timeouts, rate limits, partial responses, and upstream 5xx errors.
- Verify bounded retries/backoff, dead-letter or exhausted-job handling, cancellation, and operator recovery.
- Run baseline, peak, stress, and soak tests; record throughput, p50/p95/p99 latency, error rate, CPU, memory, disk, DB/WAL growth, and queue age.
- Verify resource limits and backpressure prevent unbounded memory, queue, or database growth.
- Run concurrent worker and multi-user tests; verify no cross-tenant or cross-user data leakage.
- Retain test scripts, sanitized fixtures, raw results, and capacity conclusions.

## 6. Rollback and change management

### Required implementation
- Version and checksum every deployable artifact; verify provenance before installation.
- Define backward-compatible migration policy and tested recovery path for failed migrations.
- Keep a known-good artifact and configuration snapshot available.
- Document rollback authority, decision criteria, and communication/escalation path.

### Drill and pass criteria
- Deploy a staging candidate, inject a controlled failure, and execute rollback.
- Verify restored service functionality and data consistency after rollback.
- Demonstrate that rollback does not silently discard accepted jobs or corrupt database state.
- Record elapsed rollback time and any manual intervention.

## Evidence register

For each gate, retain:
- Environment identifier and immutable artifact SHA-256.
- Date/time in UTC, operator, reviewer, and exact commands/scripts.
- Raw logs and machine-readable results, sanitized of secrets.
- Pass/fail outcome, measured RPO/RTO or performance values, and deviations.
- Remediation owner and retest evidence for every failure.

## P1 exit criteria

P1 may be marked accepted only when all six gates pass in staging, evidence is retained, security findings are triaged with no unresolved critical/high-risk issue, and an authorized reviewer signs off. A green unit-test/security CI run alone is insufficient. Public deployment and P2 remain blocked until then.
