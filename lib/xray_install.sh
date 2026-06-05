#!/usr/bin/env bash

xray_systemd_unit_content() {
	cat <<UNIT
[Unit]
Description=Xray Service
After=network-online.target
Wants=network-online.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${BIN_DIR}/xray run -confdir $(dirname "$XRAY_CONFIG_FILE")
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
UNIT
}

install_xray_core() {
	local unit_content unit_file

	if is_dry_run; then
		log "dry-run: would install or update Xray-core"
		return 0
	fi

	require_linux_install_host

	if is_test_mode; then
		log "test-mode: skipping Xray download and using mock xray"
		xray version >/dev/null 2>&1 || true
		if is_true "${MOCK_XRAY_INSTALL_WRITES_UNIT:-false}"; then
			mkdir -p "$(dirname "$XRAY_CONFIG_FILE")" "$LOG_DIR" "$SYSTEMD_DIR"
			unit_file="${SYSTEMD_DIR}/xray.service"
			unit_content="$(xray_systemd_unit_content)"
			XRAY_UNIT_FILE="$unit_file"
			XRAY_UNIT_BACKUP_PATH="$(write_systemd_unit_with_backup "$unit_file" "$unit_content")"
			export XRAY_UNIT_FILE XRAY_UNIT_BACKUP_PATH
			service_enable xray
		fi
		return 0
	fi

	install_system_dependencies

	local arch asset version_path archive tmp_dir
	arch="$(xray_asset_arch)"
	asset="Xray-linux-${arch}.zip"

	if [[ "$XRAY_VERSION" == "latest" ]]; then
		version_path="latest/download"
	else
		version_path="download/${XRAY_VERSION}"
	fi

	tmp_dir="$(mktemp -d)"
	archive="${tmp_dir}/${asset}"
	trap 'rm -rf "$tmp_dir"' RETURN

	curl -fsSL "https://github.com/XTLS/Xray-core/releases/${version_path}/${asset}" -o "$archive"
	unzip -o "$archive" xray -d "$tmp_dir" >/dev/null
	install -m 0755 "${tmp_dir}/xray" "${BIN_DIR}/xray"
	mkdir -p "$(dirname "$XRAY_CONFIG_FILE")" "$LOG_DIR"

	unit_file="${SYSTEMD_DIR}/xray.service"
	unit_content="$(xray_systemd_unit_content)"
	XRAY_UNIT_FILE="$unit_file"
	XRAY_UNIT_BACKUP_PATH="$(write_systemd_unit_with_backup "$unit_file" "$unit_content")"
	export XRAY_UNIT_FILE XRAY_UNIT_BACKUP_PATH
	service_enable xray
}

xray_asset_arch() {
	local machine
	machine="$(uname -m)"

	case "$machine" in
	x86_64 | amd64) printf '%s\n' "64" ;;
	aarch64 | arm64) printf '%s\n' "arm64-v8a" ;;
	armv7l) printf '%s\n' "arm32-v7a" ;;
	*) die "unsupported Xray architecture: ${machine}" ;;
	esac
}

generate_reality_keypair() {
	if is_dry_run; then
		REALITY_PRIVATE_KEY="${REALITY_PRIVATE_KEY:-$(random_password)}"
		REALITY_PUBLIC_KEY="${REALITY_PUBLIC_KEY:-$(random_password)}"
		return 0
	fi

	local output
	if ! output="$(xray x25519 2>&1)"; then
		diagnose_xray_x25519_failure "$output"
		return 1
	fi

	if [[ -z "${REALITY_PRIVATE_KEY:-}" ]]; then
		REALITY_PRIVATE_KEY="$(xray_x25519_extract_value "$output" private || true)"
	fi

	if [[ -z "${REALITY_PUBLIC_KEY:-}" ]]; then
		REALITY_PUBLIC_KEY="$(xray_x25519_extract_value "$output" public || true)"
	fi

	if [[ -z "$REALITY_PRIVATE_KEY" || -z "$REALITY_PUBLIC_KEY" ]]; then
		diagnose_xray_x25519_failure "$output"
		return 1
	fi
}

trim_value() {
	printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

xray_x25519_extract_value() {
	local output="$1"
	local wanted="$2"
	local line label normalized value

	while IFS= read -r line; do
		[[ "$line" == *:* ]] || continue
		label="$(trim_value "${line%%:*}")"
		value="$(trim_value "${line#*:}")"
		normalized="$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]')"

		case "${wanted}:${normalized}" in
		private:privatekey | private:"private key")
			printf '%s\n' "$value"
			return 0
			;;
		public:publickey | public:"public key" | public:"password (publickey)")
			printf '%s\n' "$value"
			return 0
			;;
		esac
	done <<<"$output"

	return 1
}

xray_x25519_output_labels() {
	local output="$1"
	local line label labels
	labels=""

	while IFS= read -r line; do
		[[ "$line" == *:* ]] || continue
		label="$(trim_value "${line%%:*}")"
		[[ -n "$label" ]] || continue
		if [[ -n "$labels" ]]; then
			labels="${labels}, ${label}"
		else
			labels="$label"
		fi
	done <<<"$output"

	printf '%s\n' "${labels:-none}"
}

diagnose_xray_x25519_failure() {
	local output="$1"
	local xray_path version_output version_line labels

	xray_path="$(command -v xray 2>/dev/null || printf 'not found')"
	version_output="$(xray version 2>/dev/null || true)"
	version_line="${version_output%%$'\n'*}"
	labels="$(xray_x25519_output_labels "$output")"
	[[ -n "$version_line" ]] || version_line="unknown"

	warn "failed to parse Reality x25519 keypair from xray output"
	warn "xray command path: ${xray_path}"
	warn "xray version: ${version_line}"
	warn "xray x25519 output labels: ${labels}"
}

rollback_xray_unit_after_keygen_failure() {
	local unit_file="${XRAY_UNIT_FILE:-${SYSTEMD_DIR:-}/xray.service}"

	if [[ -z "$unit_file" ]] || [[ ! -e "$unit_file" && -z "${XRAY_UNIT_BACKUP_PATH:-}" ]]; then
		return 0
	fi

	warn "rolling back Xray service unit after Reality key generation failure"
	service_stop xray || warn "failed to stop xray during rollback"
	service_disable_now xray || warn "failed to disable xray during rollback"
	rollback_config "${XRAY_UNIT_BACKUP_PATH:-}" "$unit_file"
	service_daemon_reload || warn "failed to reload service manager during rollback"
}

xray_test_config() {
	local config_file="$1"
	xray test -config "$config_file"
}

stage_xray_config_with_rollback() {
	local rendered="$1"
	local destination="$2"
	local service_name="$3"
	local backup_path

	backup_path="$(install_with_backup "$rendered" "$destination" "$service_name")"

	if ! xray_test_config "$destination"; then
		warn "xray config test failed; restoring previous config"
		rollback_config "$backup_path" "$destination"
		return 1
	fi

	if ! service_restart "$service_name"; then
		warn "service restart failed; restoring previous config"
		rollback_config "$backup_path" "$destination"
		return 1
	fi
}
