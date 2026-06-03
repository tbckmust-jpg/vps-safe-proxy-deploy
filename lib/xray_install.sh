#!/usr/bin/env bash

install_xray_core() {
	if is_dry_run; then
		log "dry-run: would install or update Xray-core"
		return 0
	fi

	require_linux_install_host

	if is_test_mode; then
		log "test-mode: skipping Xray download and using mock xray"
		xray version >/dev/null 2>&1 || true
		return 0
	fi

	install_system_dependencies

	local arch asset version_path archive tmp_dir unit_file
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
	write_systemd_unit "$unit_file" "[Unit]
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
WantedBy=multi-user.target"
	systemctl enable xray
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
	output="$(xray x25519)"
	REALITY_PRIVATE_KEY="${REALITY_PRIVATE_KEY:-$(printf '%s\n' "$output" | sed -n 's/^Private key:[[:space:]]*//p' | head -n 1)}"
	REALITY_PUBLIC_KEY="${REALITY_PUBLIC_KEY:-$(printf '%s\n' "$output" | sed -n 's/^Public key:[[:space:]]*//p' | head -n 1)}"

	if [[ -z "$REALITY_PRIVATE_KEY" || -z "$REALITY_PUBLIC_KEY" ]]; then
		die "failed to generate Reality x25519 keypair with xray"
	fi
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

	if ! systemctl restart "$service_name"; then
		warn "systemctl restart failed; restoring previous config"
		rollback_config "$backup_path" "$destination"
		return 1
	fi
}
