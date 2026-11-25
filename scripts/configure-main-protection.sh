#!/usr/bin/env bash
# Configure and verify required protection for the V17 main branch.
# Requires: gh, jq, an authenticated GitHub identity with repository administration:write.
set -Eeuo pipefail

readonly DEFAULT_REPO="pannaragaid-alt/pannaragaid"
readonly DEFAULT_BRANCH="main"
readonly -a REQUIRED_CHECKS=(
  "Tests and build (Python 3.11)"
  "Tests and build (Python 3.12)"
  "Ruff lint (Python 3.12)"
  "bandit security scan (Python 3.12)"
  "pip-audit security scan (Python 3.11)"
  "pip-audit security scan (Python 3.12)"
  "semgrep security scan (Python 3.12)"
)

usage() {
  cat <<'USAGE'
Usage:
  scripts/configure-main-protection.sh [--check|--apply] [owner/repo] [branch]

Options:
  --check   Read current protection and fail if the required policy is not active.
  --apply   Apply the required policy, then read it back and verify (never force-pushes).
  -h        Show this help.

Default mode is --check. --apply requires repository administration:write.
USAGE
}

mode="--check"
if [[ "${1:-}" == "--check" || "${1:-}" == "--apply" ]]; then
  mode="$1"
  shift
elif [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
repo="${1:-$DEFAULT_REPO}"
branch="${2:-$DEFAULT_BRANCH}"

if [[ "$repo" != */* || -z "${repo##*/}" || "$branch" != "main" ]]; then
  echo "ERROR: this policy is intentionally scoped to the main branch; repository must be owner/name." >&2
  exit 2
fi
for command in gh jq; do
  command -v "$command" >/dev/null 2>&1 || { echo "ERROR: required command not found: $command" >&2; exit 2; }
done
gh auth status >/dev/null

endpoint="repos/$repo/branches/$branch/protection"
policy="$(jq -n --argjson checks "$(printf '%s\n' "${REQUIRED_CHECKS[@]}" | jq -R . | jq -s .)" '{
  required_status_checks: { strict: true, contexts: $checks },
  enforce_admins: true,
  required_pull_request_reviews: {
    dismiss_stale_reviews: true,
    require_code_owner_reviews: false,
    required_approving_review_count: 1,
    require_last_push_approval: true
  },
  restrictions: null,
  allow_force_pushes: false,
  allow_deletions: false,
  block_creations: false,
  required_conversation_resolution: true,
  lock_branch: false,
  allow_fork_syncing: false
}')"

if [[ "$mode" == "--apply" ]]; then
  echo "Applying main-branch protection to $repo..."
  printf '%s\n' "$policy" | gh api --method PUT -H "Accept: application/vnd.github+json" "$endpoint" --input - >/dev/null
fi

echo "Reading back branch protection..."
actual="$(gh api -H "Accept: application/vnd.github+json" "$endpoint")"
jq -e --argjson expected "$policy" '
  (.required_status_checks.strict == true) and
  ((.required_status_checks.contexts | sort) == ($expected.required_status_checks.contexts | sort)) and
  (.enforce_admins.enabled == true) and
  (.required_pull_request_reviews.required_approving_review_count >= 1) and
  (.required_pull_request_reviews.dismiss_stale_reviews == true) and
  (.required_pull_request_reviews.require_last_push_approval == true) and
  (.allow_force_pushes.enabled == false) and
  (.allow_deletions.enabled == false) and
  (.required_conversation_resolution.enabled == true)
' <<<"$actual" >/dev/null || {
  echo "FAIL: branch protection is absent or does not match the required policy." >&2
  jq '{required_status_checks, enforce_admins, required_pull_request_reviews, allow_force_pushes, allow_deletions, required_conversation_resolution}' <<<"$actual" >&2
  exit 1
}

echo "PASS: $repo/$branch has strict required checks, PR approval, stale-review dismissal,"
echo "      last-push approval, admin enforcement, conversation resolution, and no force-push/deletion."
echo "Required checks:"
printf '  - %s\n' "${REQUIRED_CHECKS[@]}"
