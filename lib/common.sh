#!/usr/bin/env bash

die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

log() {
	printf '[vps-safe-proxy] %s\n' "$*"
}

warn() {
	printf '[vps-safe-proxy] WARN: %s\n' "$*" >&2
}

is_true() {
	case "${1:-}" in
	true | TRUE | 1 | yes | YES | y | Y) return 0 ;;
	*) return 1 ;;
	esac
}

is_dry_run() {
	is_true "${DRY_RUN:-false}"
}

is_test_mode() {
	is_true "${TEST_MODE:-false}"
}

is_simulation() {
	is_dry_run || is_test_mode
}

init_runtime() {
	PROJECT_ROOT="$1"
	TEST_TMP_DIR="${TEST_TMP_DIR:-${PROJECT_ROOT}/tests/tmp}"

	if is_test_mode; then
		mkdir -p "${TEST_TMP_DIR}"
		PATH="${PROJECT_ROOT}/tests/mocks:${PATH}"
		export PATH
		log "test-mode enabled; mock commands are preferred"
	fi
}

load_config_file() {
	local config_file="${CONFIG_FILE:-${PROJECT_ROOT}/config.env}"

	if is_test_mode && [[ -z "${CONFIG_FILE:-}" ]]; then
		log "test-mode: skipping config.env unless CONFIG_FILE is set"
	elif [[ -f "$config_file" ]]; then
		set -a
		# shellcheck source=/dev/null
		. "$config_file"
		set +a
	fi

	apply_default_config
	configure_runtime_paths
}

apply_default_config() {
	: "${REALITY_PORT:=443}"
	: "${HY2_PORT:=8443}"
	: "${XHTTP_HTTPS_PORT:=2053}"
	: "${REALITY_EXTERNAL_PORT:=${REALITY_PORT}}"
	: "${HY2_EXTERNAL_PORT:=${HY2_PORT}}"
	: "${XHTTP_EXTERNAL_PORT:=${XHTTP_HTTPS_PORT}}"
	: "${NAT_MODE:=false}"
	: "${REALITY_SERVER_NAME:=www.microsoft.com}"
	: "${XHTTP_INTERNAL_HOST:=127.0.0.1}"
	: "${XHTTP_INTERNAL_PORT:=10085}"
	: "${MASQUERADE_MODE:=file}"
	: "${MASQUERADE_PROXY_URL:=https://example.com}"
	: "${ENABLE_BBR:=true}"
	: "${ENABLE_FIREWALL:=${OPEN_FIREWALL:-true}}"
	: "${OPEN_FIREWALL:=${ENABLE_FIREWALL}}"
	: "${INSTALL_REALITY:=true}"
	: "${INSTALL_HY2:=true}"
	: "${INSTALL_XHTTP:=true}"
	: "${XRAY_VERSION:=latest}"
	: "${HY2_VERSION:=latest}"
}

configure_runtime_paths() {
	if is_simulation; then
		mkdir -p "$TEST_TMP_DIR"
		TEST_TMP_DIR="$(cd "$TEST_TMP_DIR" && pwd -P)"
		ROOT_DIR="${ROOT_DIR:-${TEST_TMP_DIR}/root}"
		ETC_DIR="${ETC_DIR:-${TEST_TMP_DIR}/etc}"
		LOG_DIR="${LOG_DIR:-${TEST_TMP_DIR}/log}"
		CREDENTIALS_FILE="${CREDENTIALS_FILE:-${ROOT_DIR}/vps-oneclick/credentials.txt}"
		RENDER_DIR="${RENDER_DIR:-${TEST_TMP_DIR}/render}"
		BACKUP_DIR="${BACKUP_DIR:-${TEST_TMP_DIR}/backups}"
		BIN_DIR="${BIN_DIR:-${TEST_TMP_DIR}/bin}"
		SYSTEMD_DIR="${SYSTEMD_DIR:-${ETC_DIR}/systemd/system}"
		SYSCTL_BBR_FILE="${SYSCTL_BBR_FILE:-${ETC_DIR}/sysctl.d/99-vps-oneclick-bbr.conf}"
	else
		ROOT_DIR="${ROOT_DIR:-/root/vps-oneclick}"
		ETC_DIR="${ETC_DIR:-/usr/local/etc}"
		LOG_DIR="${LOG_DIR:-/var/log/vps-oneclick}"
		CREDENTIALS_FILE="${CREDENTIALS_FILE:-/root/vps-oneclick/credentials.txt}"
		RENDER_DIR="${RENDER_DIR:-${ROOT_DIR}/rendered}"
		BACKUP_DIR="${BACKUP_DIR:-${ROOT_DIR}/backups}"
		BIN_DIR="${BIN_DIR:-/usr/local/bin}"
		SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"
		SYSCTL_BBR_FILE="${SYSCTL_BBR_FILE:-/etc/sysctl.d/99-vps-oneclick-bbr.conf}"
	fi

	APP_DATA_DIR="${APP_DATA_DIR:-$(dirname "$CREDENTIALS_FILE")}"
	XRAY_CONFIG_FILE="${XRAY_CONFIG_FILE:-${ETC_DIR}/xray/config.json}"
	XRAY_REALITY_CONFIG_FILE="${XRAY_REALITY_CONFIG_FILE:-${ETC_DIR}/xray/xray-reality-vision.json}"
	XRAY_XHTTP_CONFIG_FILE="${XRAY_XHTTP_CONFIG_FILE:-${ETC_DIR}/xray/xray-xhttp.json}"
	HY2_CONFIG_FILE="${HY2_CONFIG_FILE:-${ETC_DIR}/hysteria/hysteria-server.yaml}"
	HY2_CLIENT_CONFIG_FILE="${HY2_CLIENT_CONFIG_FILE:-${RENDER_DIR}/hysteria-client.yaml}"
	CADDY_CONFIG_FILE="${CADDY_CONFIG_FILE:-${ETC_DIR}/caddy/Caddyfile}"
	CADDY_SITE_DIR="${CADDY_SITE_DIR:-${APP_DATA_DIR}/site}"
	CADDY_RENDERED_CONFIG_FILE="${CADDY_RENDERED_CONFIG_FILE:-${RENDER_DIR}/Caddyfile}"

	if is_simulation; then
		normalize_simulation_paths
		validate_simulation_paths
	fi

	export ROOT_DIR ETC_DIR LOG_DIR CREDENTIALS_FILE RENDER_DIR BACKUP_DIR APP_DATA_DIR
	export BIN_DIR SYSTEMD_DIR SYSCTL_BBR_FILE
	export XRAY_CONFIG_FILE XRAY_REALITY_CONFIG_FILE XRAY_XHTTP_CONFIG_FILE
	export HY2_CONFIG_FILE HY2_CLIENT_CONFIG_FILE CADDY_CONFIG_FILE CADDY_SITE_DIR CADDY_RENDERED_CONFIG_FILE
}

prepare_runtime_dirs() {
	mkdir -p "$ROOT_DIR" "$ETC_DIR" "$LOG_DIR" "$RENDER_DIR" "$BACKUP_DIR"
	mkdir -p "$(dirname "$CREDENTIALS_FILE")" "$(dirname "$XRAY_CONFIG_FILE")" "$(dirname "$HY2_CONFIG_FILE")" "$(dirname "$CADDY_CONFIG_FILE")"
	mkdir -p "$BIN_DIR" "$SYSTEMD_DIR" "$(dirname "$SYSCTL_BBR_FILE")"
}

require_public_host() {
	if [[ -n "${PUBLIC_HOST:-}" ]]; then
		export PUBLIC_HOST
		return 0
	fi

	auto_detect_public_host || true

	if [[ -z "${PUBLIC_HOST:-}" ]]; then
		die "PUBLIC_HOST is required and auto-detection failed. Example: PUBLIC_HOST=1.2.3.4 ./install.sh all"
	fi
}

auto_detect_public_host() {
	local url detected

	if ! command -v curl >/dev/null 2>&1; then
		warn "curl not found; cannot auto-detect PUBLIC_HOST"
		return 1
	fi

	for url in \
		"https://api.ipify.org" \
		"https://ifconfig.co" \
		"https://icanhazip.com"; do
		detected="$(curl -4fsS --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]' || true)"
		if is_ipv4 "$detected"; then
			PUBLIC_HOST="$detected"
			export PUBLIC_HOST
			log "auto-detected PUBLIC_HOST=${PUBLIC_HOST}"
			return 0
		fi
	done

	warn "failed to auto-detect PUBLIC_HOST"
	return 1
}

is_ipv4() {
	local ip="$1"
	local IFS=.
	local -a parts
	local part

	[[ "$ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
	read -r -a parts <<<"$ip"
	[[ "${#parts[@]}" -eq 4 ]] || return 1

	for part in "${parts[@]}"; do
		[[ "$part" =~ ^[0-9]+$ ]] || return 1
		((part >= 0 && part <= 255)) || return 1
	done
}

should_install_hy2() {
	is_true "${INSTALL_HY2:-true}"
}

should_install_reality() {
	is_true "${INSTALL_REALITY:-true}"
}

should_install_xhttp() {
	is_true "${INSTALL_XHTTP:-true}"
}

write_reality_skipped_notice() {
	append_credential ''
	append_credential '[reality-vision]'
	append_credential 'Reality Vision: skipped by INSTALL_REALITY=false'
	log "Reality skipped because INSTALL_REALITY=false"
}

write_hy2_skipped_notice() {
	append_credential ''
	append_credential '[hysteria2]'
	append_credential 'Hysteria2: skipped by INSTALL_HY2=false'
	log "HY2 skipped because INSTALL_HY2=false"
}

write_xhttp_skipped_notice() {
	append_credential ''
	append_credential '[xhttp-cdn]'
	append_credential 'XHTTP: skipped by INSTALL_XHTTP=false'
	log "XHTTP skipped because INSTALL_XHTTP=false"
}

ensure_no_port_conflicts() {
	if [[ "$REALITY_PORT" == "$HY2_PORT" ]] || [[ "$REALITY_PORT" == "$XHTTP_HTTPS_PORT" ]] || [[ "$HY2_PORT" == "$XHTTP_HTTPS_PORT" ]]; then
		die "default public ports must not conflict: REALITY_PORT=${REALITY_PORT}, HY2_PORT=${HY2_PORT}, XHTTP_HTTPS_PORT=${XHTTP_HTTPS_PORT}"
	fi
}

random_hex() {
	local bytes="$1"
	if command -v openssl >/dev/null 2>&1; then
		openssl rand -hex "$bytes"
	else
		dd if=/dev/urandom bs=1 count="$bytes" 2>/dev/null | od -An -tx1 | tr -d ' \n'
	fi
}

random_uuid() {
	if command -v uuidgen >/dev/null 2>&1; then
		uuidgen | tr '[:upper:]' '[:lower:]'
	elif [[ -r /proc/sys/kernel/random/uuid ]]; then
		cat /proc/sys/kernel/random/uuid
	else
		printf '%08x-%04x-%04x-%04x-%012x\n' "$RANDOM$RANDOM" "$RANDOM" "$RANDOM" "$RANDOM" "$RANDOM$RANDOM$RANDOM"
	fi
}

random_password() {
	if command -v openssl >/dev/null 2>&1; then
		openssl rand -base64 32 | tr -d '\n'
	else
		random_hex 24
	fi
}

secure_credentials_file() {
	mkdir -p "$(dirname "$CREDENTIALS_FILE")"
	umask 077
	touch "$CREDENTIALS_FILE"
	chmod 600 "$CREDENTIALS_FILE"
}

append_credential() {
	secure_credentials_file
	printf '%s\n' "$*" >>"$CREDENTIALS_FILE"
	chmod 600 "$CREDENTIALS_FILE"
}

credentials_notice() {
	log "credentials generated; view ${CREDENTIALS_FILE}"
}

absolute_project_path() {
	case "$1" in
	/*) printf '%s\n' "$1" ;;
	*) printf '%s/%s\n' "$PROJECT_ROOT" "$1" ;;
	esac
}

normalize_simulation_paths() {
	ROOT_DIR="$(absolute_project_path "$ROOT_DIR")"
	ETC_DIR="$(absolute_project_path "$ETC_DIR")"
	LOG_DIR="$(absolute_project_path "$LOG_DIR")"
	CREDENTIALS_FILE="$(absolute_project_path "$CREDENTIALS_FILE")"
	RENDER_DIR="$(absolute_project_path "$RENDER_DIR")"
	BACKUP_DIR="$(absolute_project_path "$BACKUP_DIR")"
	APP_DATA_DIR="$(absolute_project_path "$APP_DATA_DIR")"
	XRAY_CONFIG_FILE="$(absolute_project_path "$XRAY_CONFIG_FILE")"
	XRAY_REALITY_CONFIG_FILE="$(absolute_project_path "$XRAY_REALITY_CONFIG_FILE")"
	XRAY_XHTTP_CONFIG_FILE="$(absolute_project_path "$XRAY_XHTTP_CONFIG_FILE")"
	HY2_CONFIG_FILE="$(absolute_project_path "$HY2_CONFIG_FILE")"
	HY2_CLIENT_CONFIG_FILE="$(absolute_project_path "$HY2_CLIENT_CONFIG_FILE")"
	CADDY_CONFIG_FILE="$(absolute_project_path "$CADDY_CONFIG_FILE")"
	CADDY_SITE_DIR="$(absolute_project_path "$CADDY_SITE_DIR")"
	CADDY_RENDERED_CONFIG_FILE="$(absolute_project_path "$CADDY_RENDERED_CONFIG_FILE")"
	BIN_DIR="$(absolute_project_path "$BIN_DIR")"
	SYSTEMD_DIR="$(absolute_project_path "$SYSTEMD_DIR")"
	SYSCTL_BBR_FILE="$(absolute_project_path "$SYSCTL_BBR_FILE")"
}

ensure_test_tmp_path() {
	local name="$1"
	local path="$2"

	case "$path" in
	*".."*) die "${name} must not contain .. in dry-run/test-mode: ${path}" ;;
	esac

	case "$path" in
	"$TEST_TMP_DIR" | "$TEST_TMP_DIR"/*) return 0 ;;
	esac

	die "${name} must stay under ${TEST_TMP_DIR} in dry-run/test-mode: ${path}"
}

validate_simulation_paths() {
	ensure_test_tmp_path ROOT_DIR "$ROOT_DIR"
	ensure_test_tmp_path ETC_DIR "$ETC_DIR"
	ensure_test_tmp_path LOG_DIR "$LOG_DIR"
	ensure_test_tmp_path CREDENTIALS_FILE "$CREDENTIALS_FILE"
	ensure_test_tmp_path RENDER_DIR "$RENDER_DIR"
	ensure_test_tmp_path BACKUP_DIR "$BACKUP_DIR"
	ensure_test_tmp_path XRAY_CONFIG_FILE "$XRAY_CONFIG_FILE"
	ensure_test_tmp_path XRAY_REALITY_CONFIG_FILE "$XRAY_REALITY_CONFIG_FILE"
	ensure_test_tmp_path XRAY_XHTTP_CONFIG_FILE "$XRAY_XHTTP_CONFIG_FILE"
	ensure_test_tmp_path HY2_CONFIG_FILE "$HY2_CONFIG_FILE"
	ensure_test_tmp_path HY2_CLIENT_CONFIG_FILE "$HY2_CLIENT_CONFIG_FILE"
	ensure_test_tmp_path CADDY_CONFIG_FILE "$CADDY_CONFIG_FILE"
	ensure_test_tmp_path CADDY_SITE_DIR "$CADDY_SITE_DIR"
	ensure_test_tmp_path CADDY_RENDERED_CONFIG_FILE "$CADDY_RENDERED_CONFIG_FILE"
	ensure_test_tmp_path BIN_DIR "$BIN_DIR"
	ensure_test_tmp_path SYSTEMD_DIR "$SYSTEMD_DIR"
	ensure_test_tmp_path SYSCTL_BBR_FILE "$SYSCTL_BBR_FILE"
}

require_root() {
	if is_simulation; then
		return 0
	fi

	if [[ "$(id -u)" != "0" ]]; then
		die "real installation must be run as root"
	fi
}

require_linux_install_host() {
	require_full_install_candidate
}

install_system_dependencies() {
	install_packages curl unzip openssl ca-certificates
}

write_systemd_unit() {
	local destination="$1"
	local content="$2"
	local backup_path

	backup_path="$(backup_file "$destination" "$(basename "$destination")" || true)"
	printf '%s\n' "$content" >"$destination"

	if ! service_daemon_reload; then
		warn "service daemon reload failed; restoring previous unit"
		rollback_config "$backup_path" "$destination"
		return 1
	fi
}

replace_token() {
	local file="$1"
	local name="$2"
	local value="$3"
	local escaped
	escaped="$(printf '%s' "$value" | sed -e 's/[\/&]/\\&/g')"
	sed -i "s|{{${name}}}|${escaped}|g" "$file"
}

render_template() {
	local template="$1"
	local destination="$2"
	local name

	mkdir -p "$(dirname "$destination")"
	cp "$template" "$destination"

	for name in \
		PUBLIC_HOST EMAIL HY2_DOMAIN XHTTP_DOMAIN REALITY_SERVER_NAME \
		REALITY_PORT HY2_PORT XHTTP_HTTPS_PORT XHTTP_INTERNAL_HOST XHTTP_INTERNAL_PORT \
		REALITY_UUID REALITY_PRIVATE_KEY REALITY_PUBLIC_KEY REALITY_SHORT_ID \
		HY2_PASSWORD HY2_TLS_MODE HY2_CERT_FILE HY2_KEY_FILE HY2_MASQUERADE_DIR HY2_OBFS_PASSWORD HY2_CLIENT_PORT \
		MASQUERADE_MODE MASQUERADE_PROXY_URL \
		XHTTP_UUID XHTTP_PATH CADDY_SITE_DIR CADDY_TLS_LINE CADDY_SITE_ADDRESS CADDY_SITE_NAME; do
		replace_token "$destination" "$name" "${!name:-}"
	done
}

backup_file() {
	local source="$1"
	local label="$2"
	local backup_path

	[[ -e "$source" ]] || return 0
	mkdir -p "$BACKUP_DIR"
	backup_path="${BACKUP_DIR}/${label}.$(date +%Y%m%d%H%M%S).$$.bak"
	cp -a "$source" "$backup_path"
	printf '%s\n' "$backup_path"
}

restore_backup() {
	local backup_path="$1"
	local destination="$2"

	[[ -n "$backup_path" && -e "$backup_path" ]] || return 0
	cp -a "$backup_path" "$destination"
}

rollback_config() {
	local backup_path="$1"
	local destination="$2"

	if [[ -n "$backup_path" && -e "$backup_path" ]]; then
		restore_backup "$backup_path" "$destination"
	else
		rm -f "$destination"
	fi
}

install_with_backup() {
	local rendered="$1"
	local destination="$2"
	local label="$3"
	local backup_path

	mkdir -p "$(dirname "$destination")"
	backup_path="$(backup_file "$destination" "$label" || true)"
	cp "$rendered" "$destination"
	printf '%s\n' "$backup_path"
}
