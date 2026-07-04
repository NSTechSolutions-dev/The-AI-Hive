#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-the-ai-hive}"
REPO_DIR="${REPO_DIR:-/opt/The-AI-Hive}"
WEB_ROOT="${WEB_ROOT:-/var/www/the-ai-hive}"
PRIMARY_DOMAIN="${PRIMARY_DOMAIN:-theaihive.io}"
DOMAIN_ALIASES="${DOMAIN_ALIASES:-www.theaihive.io}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"
SKIP_PACKAGE_INSTALL="${SKIP_PACKAGE_INSTALL:-0}"
SKIP_CERTBOT="${SKIP_CERTBOT:-0}"

HTTPD_SERVICE=""
HTTPD_CONF_DIR=""
HTTPD_ENABLE_CONF=0
WEB_USER=""
WEB_GROUP=""

usage() {
  cat <<USAGE
Usage: sudo ./deploy.sh [options]

End-to-end production setup for The AI Hive at ${REPO_DIR}.
The static site is published to ${WEB_ROOT} and served directly by Apache httpd.

Options:
  --repo-dir PATH          Repository path on the server (default: ${REPO_DIR})
  --web-root PATH          Apache document root (default: ${WEB_ROOT})
  --domain DOMAIN          Primary domain (default: ${PRIMARY_DOMAIN})
  --aliases "DOMAINS"      Space-separated aliases (default: ${DOMAIN_ALIASES})
  --email EMAIL            Let's Encrypt registration email
  --no-package-install     Skip OS package installation
  --skip-certbot           Skip Let's Encrypt certificate request
  -h, --help               Show this help

Optional environment variables:
  GIT_REPO_URL             Clone URL to use if ${REPO_DIR} does not exist
  CERTBOT_EMAIL            Let's Encrypt registration email
  PRIMARY_DOMAIN           Override primary domain
  DOMAIN_ALIASES           Override aliases
  WEB_ROOT                 Override Apache document root
USAGE
}

log() {
  printf '[deploy] %s\n' "$*"
}

warn() {
  printf '[deploy] WARNING: %s\n' "$*" >&2
}

die() {
  printf '[deploy] ERROR: %s\n' "$*" >&2
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-dir)
        REPO_DIR="$2"
        shift 2
        ;;
      --web-root)
        WEB_ROOT="$2"
        shift 2
        ;;
      --domain)
        PRIMARY_DOMAIN="$2"
        shift 2
        ;;
      --aliases)
        DOMAIN_ALIASES="$2"
        shift 2
        ;;
      --email)
        CERTBOT_EMAIL="$2"
        shift 2
        ;;
      --no-package-install)
        SKIP_PACKAGE_INSTALL=1
        shift
        ;;
      --skip-certbot)
        SKIP_CERTBOT=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "run this script with sudo or as root"
}

install_packages() {
  if [[ "${SKIP_PACKAGE_INSTALL}" == "1" ]]; then
    log "Skipping package installation."
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y apache2 certbot python3-certbot-apache git curl ca-certificates rsync
    a2enmod headers rewrite ssl >/dev/null
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    dnf install -y httpd mod_ssl certbot python3-certbot-apache git curl ca-certificates rsync
    return
  fi

  if command -v yum >/dev/null 2>&1; then
    yum install -y httpd mod_ssl certbot python3-certbot-apache git curl ca-certificates rsync
    return
  fi

  die "unsupported OS: expected apt-get, dnf, or yum"
}

detect_httpd() {
  if [[ -d /etc/apache2 ]]; then
    HTTPD_SERVICE="apache2"
    HTTPD_CONF_DIR="/etc/apache2/sites-available"
    HTTPD_ENABLE_CONF=1
    WEB_USER="www-data"
    WEB_GROUP="www-data"
    return
  fi

  HTTPD_SERVICE="httpd"
  HTTPD_CONF_DIR="/etc/httpd/conf.d"
  HTTPD_ENABLE_CONF=0
  WEB_USER="apache"
  WEB_GROUP="apache"
}

prepare_repo() {
  if [[ -d "${REPO_DIR}/.git" ]]; then
    log "Using existing repository at ${REPO_DIR}."
  elif [[ -n "${GIT_REPO_URL:-}" ]]; then
    mkdir -p "$(dirname "${REPO_DIR}")"
    git clone "${GIT_REPO_URL}" "${REPO_DIR}"
  else
    die "${REPO_DIR} does not exist. Clone the repo there first, or set GIT_REPO_URL."
  fi

  [[ -f "${REPO_DIR}/index.html" ]] || die "missing ${REPO_DIR}/index.html"
  [[ -f "${REPO_DIR}/health.html" ]] || die "missing ${REPO_DIR}/health.html"
  [[ -f "${REPO_DIR}/scripts/publish-static-site.sh" ]] || die "missing static publish script"
  [[ -f "${REPO_DIR}/ops/systemd/${APP_NAME}.service" ]] || die "missing systemd service template"
  [[ -f "${REPO_DIR}/ops/httpd/${APP_NAME}.conf" ]] || die "missing httpd vhost template"
}

install_systemd_service() {
  log "Installing systemd service."
  sed \
    -e "s#/opt/The-AI-Hive#${REPO_DIR}#g" \
    -e "s#/var/www/the-ai-hive#${WEB_ROOT}#g" \
    "${REPO_DIR}/ops/systemd/${APP_NAME}.service" > "/etc/systemd/system/${APP_NAME}.service"

  systemctl daemon-reload
  systemctl enable "${APP_NAME}.service"
}

install_httpd_vhost() {
  local target_conf

  log "Installing httpd virtual host for ${PRIMARY_DOMAIN}."
  mkdir -p "${HTTPD_CONF_DIR}"
  mkdir -p "${WEB_ROOT}"
  target_conf="${HTTPD_CONF_DIR}/${APP_NAME}.conf"

  sed \
    -e "s#www.theaihive.io#${DOMAIN_ALIASES}#g" \
    -e "s#theaihive.io#${PRIMARY_DOMAIN}#g" \
    -e "s#/var/www/the-ai-hive#${WEB_ROOT}#g" \
    "${REPO_DIR}/ops/httpd/${APP_NAME}.conf" > "${target_conf}"

  if [[ "${HTTPD_ENABLE_CONF}" == "1" ]]; then
    a2ensite "${APP_NAME}.conf" >/dev/null
    a2dissite 000-default.conf >/dev/null 2>&1 || true
  fi

  apachectl configtest
}

publish_static_site() {
  log "Publishing static files through systemd."
  systemctl restart "${APP_NAME}.service"
}

start_services() {
  log "Starting site service and httpd."
  systemctl enable --now "${HTTPD_SERVICE}"
  publish_static_site
  systemctl reload "${HTTPD_SERVICE}" || systemctl restart "${HTTPD_SERVICE}"
}

host_ips() {
  hostname -I 2>/dev/null | tr ' ' '\n' | sed '/^$/d' || true
}

domain_ips() {
  getent ahosts "$1" 2>/dev/null | awk '{print $1}' | sort -u || true
}

domain_points_here() {
  local domain="$1"
  local domain_ip host_ip

  while read -r domain_ip; do
    [[ -n "${domain_ip}" ]] || continue
    while read -r host_ip; do
      [[ "${domain_ip}" == "${host_ip}" ]] && return 0
    done < <(host_ips)
  done < <(domain_ips "${domain}")

  return 1
}

run_certbot() {
  local email_args domain_args alias

  if [[ "${SKIP_CERTBOT}" == "1" ]]; then
    log "Skipping Certbot."
    return
  fi

  if ! command -v certbot >/dev/null 2>&1; then
    warn "certbot is not installed; HTTP vhost is configured but HTTPS was not requested."
    return
  fi

  if ! domain_points_here "${PRIMARY_DOMAIN}"; then
    warn "DNS for ${PRIMARY_DOMAIN} does not resolve to this server yet; skipping Certbot for now."
    warn "Create A/AAAA records for ${PRIMARY_DOMAIN} and aliases, then rerun: sudo ${REPO_DIR}/deploy.sh"
    return
  fi

  domain_args=(-d "${PRIMARY_DOMAIN}")
  for alias in ${DOMAIN_ALIASES}; do
    domain_args+=(-d "${alias}")
  done

  if [[ -n "${CERTBOT_EMAIL}" ]]; then
    email_args=(--email "${CERTBOT_EMAIL}")
  else
    email_args=(--register-unsafely-without-email)
  fi

  log "Requesting/renewing Let's Encrypt certificate."
  certbot --apache --non-interactive --agree-tos --redirect --keep-until-expiring "${email_args[@]}" "${domain_args[@]}" \
    || warn "Certbot failed. Verify DNS/firewall and rerun deploy.sh."
}

verify_health() {
  log "Checking httpd health endpoint."
  curl --fail --silent --show-error --header "Host: ${PRIMARY_DOMAIN}" "http://127.0.0.1/health.html" >/dev/null
}

main() {
  parse_args "$@"
  require_root
  install_packages
  detect_httpd
  prepare_repo
  install_httpd_vhost
  install_systemd_service
  start_services
  run_certbot
  verify_health

  log "Deployment finished for ${PRIMARY_DOMAIN} from ${REPO_DIR}."
}

main "$@"
