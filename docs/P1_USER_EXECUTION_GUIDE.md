# P1 User Execution Guide — External Prerequisites and Acceptance

Status: **Execution guide; P1 acceptance remains OPEN**  
Scope: V17 Global Growth Engine 0.7.0 P1.  
Purpose: make the remaining operator-owned work deterministic. This guide does not assert that infrastructure, credentials, drills, or governance have already been completed.

## 0. Safety rules

1. Do not paste API keys, OAuth client secrets, refresh tokens, private keys, database files, or production data into chat, GitHub issues, pull requests, or source control.
2. Store secrets only in the approved secret manager or the host's protected systemd credential mechanism. Give each service its own least-privilege identity.
3. Use staging accounts, synthetic data, and provider sandbox credentials wherever available. Do not use production credentials for initial acceptance.
4. Keep the dashboard bound to loopback. Do not expose it through a public IP, tunnel, or reverse proxy until OIDC/RBAC and the negative authorization tests in Gate 4 have passed.
5. Do not publish packages or create a public release. CI wheel builds are validation artifacts only.
6. Do not proceed to P2 while any P1 gate is open.

## 1. Prepare the operator-owned prerequisites

Create an inventory and assign an owner for each item. Record secret *references* and metadata, never secret values.

| Area | What the operator must prepare | Minimum safe form |
|---|---|---|
| Host | Dedicated Linux staging host, supported Python, systemd, persistent encrypted disk, firewall and DNS | Non-root service identities; inbound access closed except approved admin path |
| Application configuration | Environment-specific non-secret settings and approved egress destinations | Separate staging and production configuration; documented owner |
| Google Cloud Translation | GCP project, Translation API enabled, billing/quota approval, service identity and ADC | Workload identity or short-lived ADC; no downloaded long-lived key unless unavoidable |
| YouTube | Google OAuth consent configuration, OAuth client, redirect URI, test users, YouTube Data API enabled | Read-only scopes only; staging test account; exact callback URI |
| Firecrawl | API account/key and approved crawl/search domain policy | Secret-manager reference; quota and domain allowlist |
| OIDC/SSO | Identity provider tenant/issuer, client ID, client secret reference, callback/logout URLs, signing/JWKS discovery, test users/groups | Separate staging client; authorization-code flow; PKCE; MFA policy |
| Backup | External object storage bucket/account, encryption/KMS key, lifecycle/retention policy, restore identity | Separate failure domain and separate key administration; immutable/versioned retention where supported |
| Observability | Log sink, metrics backend, dashboard, alert receiver/on-call owner | TLS transport, access control, retention, tested delivery |
| Staging tests | Provider sandbox/test accounts, synthetic fixtures, workload profile, capacity budget | No production customer data or production secrets |
| Governance | Repository administrator, one independent authorized reviewer, CI status-check permissions | Reviewer must not be the author of the change being approved |

Before creating credentials, decide who owns rotation, revocation, incident response, quota/billing, and expiry monitoring. If a provider cannot issue a sandbox credential, obtain explicit approval for a restricted test account and cap its quota.

## 2. Configure GitHub repository governance (Gate 7)

An authorized repository administrator must perform these steps in the GitHub web UI:

1. Open the repository: https://github.com/pannaragaid-alt/pannaragaid
2. Open **Settings → Rules → Rulesets** (or **Settings → Branches** if using classic branch protection).
3. Create a branch ruleset targeting the exact branch name `main`.
4. Set enforcement to **Active**.
5. Enable **Require a pull request before merging** and require at least **1 approval** from an authorized reviewer. Enable dismissal of stale approvals after new commits and require approval of the most recent reviewable push if available.
6. Enable **Require status checks to pass** and **Require branches to be up to date before merging**.
7. Add these seven check names exactly as reported by the workflow:
   - `Tests and build (Python 3.11)`
   - `Tests and build (Python 3.12)`
   - `Ruff lint (Python 3.12)`
   - `bandit security scan (Python 3.12)`
   - `pip-audit security scan (Python 3.11)`
   - `pip-audit security scan (Python 3.12)`
   - `semgrep security scan (Python 3.12)`
8. Block force pushes and branch deletion. Do not add routine bypass actors. If an emergency bypass is unavoidable, scope it to a named break-glass role and audit every use; normal development must not bypass the rule.
9. Save the ruleset. Export or capture the complete configuration and record its timestamp and administrator.
10. Verify it operationally: a normal contributor cannot push directly to `main`; a PR with a failed required check is blocked; a PR with all checks passing still requires the authorized approval.

**Evidence to retain:** ruleset JSON/export or screenshots showing target branch, active enforcement, all seven checks, approval requirement, up-to-date requirement, and force-push/deletion restrictions; plus links to the three verification attempts. Do not mark Gate 7 passed from a screenshot of settings alone.

## 3. Install and validate the staging host (Gates 1–6)

1. Provision the host from the approved baseline image. Apply OS security updates, time synchronization, host firewall, disk encryption, and restricted administrator access.
2. Create dedicated non-root identities for dashboard and backup. Do not run the application as root.
3. Create application data/config directories with owner-only permissions. Keep database, backups, logs, and secrets on separate paths or storage policies as appropriate.
4. Install the exact P1.4.1 archive whose SHA-256 is `49c721d6d88912893a22957579da2e9075ec39505e2c33f78355a978f64dfdc3`. Verify the digest before extraction. Do not use an unverified re-packed archive.
5. Install dependencies using the documented project installation procedure in the source package. Run `v17 doctor --json`; stop on any failed check. Retain the sanitized JSON output.
6. Install the dashboard and backup systemd units from the archive's `deploy/systemd/` directory. Review the unit files and run `systemd-analyze verify` before enabling them.
7. Configure systemd credentials using `LoadCredential=` or the documented credential-file mechanism. Credential files must be regular files, root/service-readable only, and never placed in command arguments or environment values.
8. Keep dashboard bound to `127.0.0.1`. Confirm with `ss -ltnp` that no public interface is listening.
9. Enable the backup timer only after external storage, encryption, retention, and restore identity are configured. A successful local backup is not a passing backup gate.
10. Record package/archive digest, OS image, Python version, unit-file checksums, configuration version, and operator.

## 4. Configure identity and provider integrations (Gates 4–5)

1. Create a dedicated staging OIDC client in the IdP. Register only the exact staging callback and logout URLs. Use authorization code + PKCE; enable MFA and short session lifetime according to organizational policy.
2. Map IdP groups to application roles. Define explicit permissions for administrator, operator, analyst, and read-only roles; default unknown users to deny.
3. Store the client secret in the secret manager and inject it by reference. Never commit it or paste it into a ticket.
4. Create at least two test identities with different roles plus one disabled/revoked identity.
5. Configure Google Cloud Translation with a dedicated GCP project and workload identity/ADC. Enable the API and quota; verify the service identity can translate only the approved test content. No project or credentials means this integration remains unverified.
6. Configure YouTube OAuth with read-only scopes, approved test users, and exact callback URI. Complete consent/token refresh/revocation tests using the staging account.
7. Configure Firecrawl using a scoped API key and explicit domain allowlist. Verify quota handling, timeout, upstream 4xx/5xx, malformed response, and provider outage behavior.
8. For each integration, record provider, project/tenant identifier (non-secret), scopes, credential reference, expiry/rotation owner, quota, and sanitized test outcome. Never record the token or secret.

## 5. Configure backups and observability (Gates 1 and 3)

### Backup

1. Create an external storage destination in a separate failure domain from the staging host.
2. Configure server-side encryption with a KMS key whose permissions are separate from the application service identity.
3. Set retention, versioning/immutability if available, lifecycle deletion, and least-privilege upload/read/restore roles.
4. Configure the backup timer and alert on missed or failed runs.
5. Run a backup and verify object checksum, encryption, metadata, and access policy.
6. Restore into a clean isolated staging instance using only the documented recovery procedure.
7. Run SQLite integrity and foreign-key checks plus application-level checks for schema version, representative synthetic records, job state/leases, report readability, and doctor status.
8. Simulate an unusable newest backup and restore the previous known-good backup.
9. Measure actual RPO and RTO. The service owner must approve explicit targets before the drill; do not invent targets after observing results.

### Logs, metrics, alerts

1. Configure structured logs with UTC timestamp, severity, component, correlation/request/job ID, and sanitized error context.
2. Confirm redaction of access tokens, refresh tokens, client secrets, authorization headers, personal data, and provider payloads before forwarding.
3. Configure centralized log retention and restricted access.
4. Export queue depth/age, throughput, retries, failures, lease expiry, request latency, provider error rate, worker saturation, DB/WAL size, disk space, and process health.
5. Define SLOs and alert thresholds with the service owner.
6. Send test alerts for process failure, queue backlog, repeated provider errors, disk pressure, and missed backup. Verify delivery, acknowledgement, deduplication, escalation, and recovery notification.
7. Search logs for a synthetic request through its downstream job and prove correlation without sensitive payload leakage.

## 6. Execute the acceptance drills (Gates 1–6)

Use only staging and synthetic data. Run each drill separately; preserve raw sanitized output and record start/end time in UTC.

| Gate | Required drill | Pass evidence |
|---|---|---|
| 1 Backup/restore | Full backup, clean restore, bad-latest fallback, retention and external-copy check | Checksums, SQLite integrity/FK output, application invariants, measured RPO/RTO, reviewer sign-off |
| 2 Supervision/recovery | Start/stop/restart, graceful shutdown, kill during synthetic job, lease expiry/reclaim, DB-write interruption | systemd journal, job/lease timeline, DB integrity, no duplicate side effects, restart throttling |
| 3 Observability | Correlated request/job trace and five alert scenarios | Sanitized log query, metric snapshots, alert delivery/acknowledgement timestamps |
| 4 Auth/RBAC | Anonymous denial and positive/negative role matrix for every sensitive operation; CSRF/session/IDOR/revocation tests | Automated test results and edge/application denial evidence; no unauthorized read/write/export/job control |
| 5 Integration/load | Provider happy path and auth expiry, invalid key, timeout, 429, partial response, 5xx; baseline/peak/stress/soak; concurrent users | Test scripts, sanitized provider outcomes, p50/p95/p99, throughput, errors, CPU/memory/disk/DB growth, isolation results |
| 6 Rollback | Deploy candidate, inject controlled failure, rollback to known-good artifact/config | Artifact checksums, migration/data consistency checks, service restoration, elapsed time, manual actions |

Any failed or inconclusive test leaves that gate **OPEN**. File a remediation, repeat the drill, and retain both failed and passing evidence. Do not delete failed evidence.

## 7. Evidence package and handoff

Create an access-controlled evidence directory or ticket collection with this structure:

```text
P1-acceptance/
  manifest.md
  gate-1-backup-restore/
  gate-2-supervision-recovery/
  gate-3-observability/
  gate-4-auth-rbac/
  gate-5-provider-load/
  gate-6-rollback/
  gate-7-github-governance/
  signoff/
```

For every artifact record: environment ID, archive SHA-256, UTC timestamp, operator, reviewer, exact command or test, raw sanitized result, pass/fail, deviation, remediation, and retest link. Keep sensitive raw logs in the approved restricted system, not in this repository.

The service owner and an independent authorized reviewer must sign the final acceptance. The acceptance reviewer must confirm all seven gates pass and no unresolved critical/high-severity security finding remains.

## 8. Exact handoff package to provide to the implementation team

Provide **references and non-secret metadata only**:

- Staging host OS/version, architecture, deployment region, DNS name, and resource limits.
- Secret-manager product, secret reference names, and service identities.
- GCP project ID, enabled API status, workload identity/ADC method, and quota approval.
- YouTube OAuth client ID (not secret), redirect URI, test account status, and approved read-only scopes.
- Firecrawl account/key reference, approved domains, and quota.
- OIDC issuer URL, client ID, callback/logout URLs, group-to-role mapping, test identities, and secret reference.
- External backup storage provider/bucket identifier, KMS key reference, retention policy, and restore role.
- Log/metrics/alert endpoint identifiers, retention, alert receiver, and on-call owner.
- Approved RPO/RTO, SLO, workload profile, concurrency, and capacity budget.
- Authorized GitHub administrator and independent reviewer identity.
- Change window, rollback authority, and evidence repository/ticket location.

Never send secret values. Use the secret manager's access grant or a controlled credential injection path.

## 9. Current completion rule

The P1.4.1 hosted CI run #47 passed all seven CI jobs and 520 tests on Python 3.11 and 3.12. This is code validation only. It does not satisfy the seven operational acceptance gates.

P1 remains **OPEN** until all seven gates have objective evidence and independent sign-off. Public deployment and P2 remain blocked. No package registry publication or public release is permitted by this work.
