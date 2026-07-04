#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-the-ai-hive}"
REPO_DIR="${REPO_DIR:-/opt/The-AI-Hive}"
PRIMARY_DOMAIN="${PRIMARY_DOMAIN:-theaihive.io}"
REMOTE="${REMOTE:-origin}"
SKIP_CERTBOT="${SKIP_CERTBOT:-1}"
ALLOW_DIRTY_UPDATE="${ALLOW_DIRTY_UPDATE:-0}"

log() {
  printf '[update] %s\n' "$*"
}

die() {
  printf '[update] ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "run this script with sudo or as root"
}

httpd_service_name() {
  if [[ -d /etc/apache2 ]]; then
    printf 'apache2'
    return
  fi

  printf 'httpd'
}

ensure_clean_worktree() {
  local status

  status="$(git status --porcelain)"
  if [[ -n "${status}" && "${ALLOW_DIRTY_UPDATE}" != "1" ]]; then
    printf '%s\n' "${status}" >&2
    die "repository has local changes; set ALLOW_DIRTY_UPDATE=1 to deploy anyway"
  fi
}

pull_latest() {
  local branch

  branch="$(git rev-parse --abbrev-ref HEAD)"
  [[ "${branch}" != "HEAD" ]] || die "repository is in detached HEAD state"

  git fetch "${REMOTE}" --prune
  git pull --ff-only "${REMOTE}" "${branch}"
}

redeploy() {
  SKIP_PACKAGE_INSTALL=1 SKIP_CERTBOT="${SKIP_CERTBOT}" bash "${REPO_DIR}/deploy.sh" --no-package-install --skip-certbot
  systemctl restart the-ai-hive.service
  systemctl reload "$(httpd_service_name)" || systemctl restart "$(httpd_service_name)"
}

verify_health() {
  curl --fail --silent --show-error --header "Host: theaihive.io" http://127.0.0.1/health.html >/dev/null
  curl --fail --silent --show-error --header "Host: ${PRIMARY_DOMAIN}" http://127.0.0.1/health.html >/dev/null
}

main() {
  require_root
  [[ -d "${REPO_DIR}/.git" ]] || die "${REPO_DIR} is not a git repository"
  cd "${REPO_DIR}"

  ensure_clean_worktree
  pull_latest
  redeploy
  verify_health

  log "Update deployed from ${REPO_DIR}."
}

main "$@"
