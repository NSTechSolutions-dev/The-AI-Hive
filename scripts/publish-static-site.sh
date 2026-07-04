#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${SOURCE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
WEB_ROOT="${WEB_ROOT:-/var/www/the-ai-hive}"
WEB_USER="${WEB_USER:-}"
WEB_GROUP="${WEB_GROUP:-${WEB_USER}}"

log() {
  printf '[publish] %s\n' "$*"
}

die() {
  printf '[publish] ERROR: %s\n' "$*" >&2
  exit 1
}

[[ -f "${SOURCE_DIR}/index.html" ]] || die "missing ${SOURCE_DIR}/index.html"
[[ -f "${SOURCE_DIR}/health.html" ]] || die "missing ${SOURCE_DIR}/health.html"
command -v rsync >/dev/null 2>&1 || die "rsync is required to publish static files"

mkdir -p "${WEB_ROOT}"

rsync -a --delete \
  --exclude='.git/' \
  --exclude='.*' \
  --exclude='ops/' \
  --exclude='scripts/' \
  --exclude='deploy.sh' \
  --exclude='update.sh' \
  --exclude='README.md' \
  "${SOURCE_DIR}/" "${WEB_ROOT}/"

find "${WEB_ROOT}" -type d -exec chmod 755 {} +
find "${WEB_ROOT}" -type f -exec chmod 644 {} +

if [[ -n "${WEB_USER}" ]] && id -u "${WEB_USER}" >/dev/null 2>&1; then
  chown -R "${WEB_USER}:${WEB_GROUP}" "${WEB_ROOT}"
fi

log "Published ${SOURCE_DIR} to ${WEB_ROOT}."
