# Repository governance: main branch protection

Status at authoring: **OPEN until an administrator runs the apply command and the read-back check passes**.

This repository has seven required CI checks. A successful workflow run does not itself enforce that future changes pass those checks. GitHub branch protection is a separate repository setting.

## Policy applied by the helper

The helper at `scripts/configure-main-protection.sh` configures and verifies:

- Pull requests are required for changes to `main`.
- At least one approval is required.
- Stale approvals are dismissed when new commits are pushed.
- The most recent push must be approved by someone other than its pusher.
- The branch must be up to date before merge.
- All seven named CI checks are required.
- Administrators are subject to the protection.
- Force pushes and branch deletion are disabled.
- All review conversations must be resolved.

It does not create users/reviewers, approve pull requests, change repository visibility, configure identity providers, or grant permissions. The repository owner must ensure at least one eligible independent reviewer exists.

## Administrator procedure (GitHub CLI)

Run these commands on a trusted workstation with access to the repository:

1. Install GitHub CLI (`gh`) and `jq`.
2. Authenticate as a repository administrator. Use the interactive login flow; do not paste a personal access token into chat, source files, shell history, or logs:

   ```bash
   gh auth login
   gh auth status
   ```

   The authenticated identity needs permission to administer repository settings. For a fine-grained token, grant repository **Administration: Read and write** (and repository metadata access). Organization policy may additionally require an organization owner to authorize the token.

3. Obtain the governance helper from the repository:

   ```bash
   git clone https://github.com/pannaragaid-alt/pannaragaid.git
   cd pannaragaid
   git checkout main
   ```

4. First inspect current state without changing it:

   ```bash
   bash scripts/configure-main-protection.sh --check
   ```

   A failure here is expected while the protection rule is not configured. It is not a reason to skip the apply step.

5. Apply the policy:

   ```bash
   bash scripts/configure-main-protection.sh --apply
   ```

   The command calls GitHub's branch-protection API. It will fail closed if the identity lacks permission or GitHub rejects the policy. It then reads the settings back and validates the exact seven check names and protection flags.

6. Independently verify in the GitHub UI:

   - Open **Settings → Branches** in the repository.
   - Locate the rule for `main`.
   - Confirm pull requests, one approval, stale-review dismissal, approval of the latest push, up-to-date branches, all seven required checks, administrator enforcement, conversation resolution, and disabled force pushes/deletion.
   - Confirm the rule is active for the exact branch `main`, not merely a similarly named pattern.

7. Exercise the policy with a test pull request:

   - A PR with a deliberately failing required check must not be mergeable.
   - A PR without an approval must not be mergeable.
   - A PR with all required checks passing and an eligible independent approval should become mergeable.
   - Do not test by force-pushing or deleting `main`.

8. Retain evidence:
   - Output of the successful `--apply` run.
   - Screenshot or exported view of the active rule.
   - Test PR URL and its required-check/review state.
   - UTC timestamp and administrator/reviewer identity.

## Troubleshooting

- **403 / Resource not accessible:** the authenticated identity or token lacks repository administration permission, or organization policy blocks the integration. Ask a repository/organization owner to perform the steps.
- **Required check name not found:** run the workflow on a PR and compare the exact GitHub status-check context names. Do not guess or shorten names. Update the helper and this runbook together only after confirming the actual contexts.
- **No eligible reviewer:** add at least one trusted collaborator/team with repository review permission. Do not weaken the approval requirement to make the gate green.
- **Check passes but rule remains open:** inspect the exact `main` rule and repeat the script's read-back check. A successful API write without successful read-back is not acceptance.

## Security notes

- Never grant broad bypass privileges as a convenience.
- Do not store GitHub tokens in the repository.
- Do not use force-push to repair governance configuration.
- Branch protection is only one gate; it does not replace staging, backup/restore, authentication/RBAC, observability, load testing, or rollback drills.
