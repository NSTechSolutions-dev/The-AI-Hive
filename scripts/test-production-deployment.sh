#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "${ROOT_DIR}/${path}" ]] || fail "missing ${path}"
}

assert_executable() {
  local path="$1"
  [[ -x "${ROOT_DIR}/${path}" ]] || fail "${path} is not executable"
}

assert_contains() {
  local path="$1"
  local expected="$2"
  grep -Fq "$expected" "${ROOT_DIR}/${path}" || fail "${path} does not contain: ${expected}"
}

assert_file "deploy.sh"
assert_file "update.sh"
assert_file "ops/systemd/the-ai-hive.service"
assert_file "ops/httpd/the-ai-hive.conf"
assert_file "health.html"

assert_executable "deploy.sh"
assert_executable "update.sh"

assert_contains "deploy.sh" "REPO_DIR=\"\${REPO_DIR:-/opt/The-AI-Hive}\""
assert_contains "deploy.sh" "WEB_ROOT=\"\${WEB_ROOT:-/var/www/the-ai-hive}\""
assert_contains "deploy.sh" "PRIMARY_DOMAIN=\"\${PRIMARY_DOMAIN:-theaihive.io}\""
assert_contains "deploy.sh" "install_httpd_vhost"
assert_contains "deploy.sh" "install_systemd_service"
assert_contains "deploy.sh" "publish_static_site"
assert_contains "deploy.sh" "run_certbot"

assert_contains "update.sh" "git pull --ff-only"
assert_contains "update.sh" "systemctl restart the-ai-hive.service"
assert_contains "update.sh" "curl --fail --silent --show-error --header \"Host: theaihive.io\" http://127.0.0.1/health.html"

assert_contains "ops/systemd/the-ai-hive.service" "WorkingDirectory=/opt/The-AI-Hive"
assert_contains "ops/systemd/the-ai-hive.service" "ExecStart=/bin/bash /opt/The-AI-Hive/scripts/publish-static-site.sh"

assert_contains "ops/httpd/the-ai-hive.conf" "ServerName theaihive.io"
assert_contains "ops/httpd/the-ai-hive.conf" "ServerAlias www.theaihive.io"
assert_contains "ops/httpd/the-ai-hive.conf" "DocumentRoot /var/www/the-ai-hive"
assert_contains "ops/httpd/the-ai-hive.conf" "<Directory /var/www/the-ai-hive>"

[[ ! -f "${ROOT_DIR}/Dockerfile" ]] || fail "Dockerfile should not exist"
[[ ! -f "${ROOT_DIR}/docker-compose.yml" ]] || fail "docker-compose.yml should not exist"
[[ ! -f "${ROOT_DIR}/.dockerignore" ]] || fail ".dockerignore should not exist"

if grep -R -n -E 'docker|compose|8089|ProxyPass' \
  "${ROOT_DIR}/deploy.sh" \
  "${ROOT_DIR}/update.sh" \
  "${ROOT_DIR}/ops" \
  "${ROOT_DIR}/scripts/publish-static-site.sh" >/tmp/the-ai-hive-docker-scan.txt; then
  cat /tmp/the-ai-hive-docker-scan.txt >&2
  fail "deployment files still contain Docker/proxy references"
fi

printf 'Production deployment files verified.\n'
