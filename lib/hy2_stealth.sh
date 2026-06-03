#!/usr/bin/env bash

install_hysteria2_core() {
	if is_dry_run; then
		log "dry-run: would install Hysteria2"
		return 0
	fi

	require_linux_install_host

	if is_test_mode; then
		log "test-mode: skipping Hysteria2 download and using mock hysteria"
		hysteria version >/dev/null 2>&1 || true
		return 0
	fi

	install_system_dependencies

	local arch version_path url tmp_file unit_file
	arch="$(hy2_asset_arch)"

	if [[ "$HY2_VERSION" == "latest" ]]; then
		version_path="latest/download"
	else
		version_path="download/${HY2_VERSION}"
	fi

	url="https://github.com/apernet/hysteria/releases/${version_path}/hysteria-linux-${arch}"
	tmp_file="$(mktemp)"
	trap 'rm -f "$tmp_file"' RETURN

	curl -fsSL "$url" -o "$tmp_file"
	install -m 0755 "$tmp_file" "${BIN_DIR}/hysteria"
	mkdir -p "$(dirname "$HY2_CONFIG_FILE")" "$LOG_DIR"

	unit_file="${SYSTEMD_DIR}/hysteria-server.service"
	write_systemd_unit "$unit_file" "[Unit]
Description=Hysteria2 Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BIN_DIR}/hysteria server --config ${HY2_CONFIG_FILE}
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target"
	systemctl enable hysteria-server
}

hy2_asset_arch() {
	local machine
	machine="$(uname -m)"

	case "$machine" in
	x86_64 | amd64) printf '%s\n' "amd64" ;;
	aarch64 | arm64) printf '%s\n' "arm64" ;;
	armv7l) printf '%s\n' "armv7" ;;
	*) die "unsupported Hysteria2 architecture: ${machine}" ;;
	esac
}

ensure_hy2_self_signed_cert() {
	if [[ "$HY2_TLS_MODE" != "self-signed" ]]; then
		return 0
	fi

	if is_dry_run; then
		return 0
	fi

	mkdir -p "$(dirname "$HY2_CERT_FILE")"

	if is_test_mode; then
		printf '%s\n' "TEST CERT" >"$HY2_CERT_FILE"
		printf '%s\n' "TEST KEY" >"$HY2_KEY_FILE"
		chmod 600 "$HY2_KEY_FILE"
		return 0
	fi

	openssl req -x509 -newkey rsa:2048 -nodes \
		-keyout "$HY2_KEY_FILE" \
		-out "$HY2_CERT_FILE" \
		-days 365 \
		-subj "/CN=${HY2_DOMAIN}"
	chmod 600 "$HY2_KEY_FILE"
}

warn_udp_port_state() {
	local port="$1"

	if is_dry_run; then
		log "dry-run: would inspect UDP ${port}; UDP availability is not assumed"
		return 0
	fi

	if command -v ss >/dev/null 2>&1 && ss -H -lun | grep -Eq "[:.]${port}[[:space:]]"; then
		warn "UDP ${port} appears to be in use; please verify Hysteria2 can bind it"
	else
		warn "UDP ${port} cannot be fully verified locally; also check provider firewall and routing"
	fi
}

stage_hy2_config_with_rollback() {
	local rendered="$1"
	local backup_path

	backup_path="$(install_with_backup "$rendered" "$HY2_CONFIG_FILE" hysteria-server)"

	if ! systemctl restart hysteria-server; then
		warn "systemctl restart hysteria-server failed; restoring previous config"
		rollback_config "$backup_path" "$HY2_CONFIG_FILE"
		return 1
	fi
}

install_hy2_stealth() {
	ensure_no_port_conflicts
	prepare_runtime_dirs

	HY2_PASSWORD="${HY2_PASSWORD:-$(random_password)}"
	HY2_OBFS_PASSWORD="${HY2_OBFS_PASSWORD:-$(random_password)}"
	HY2_CLIENT_PORT="$(effective_export_port "$HY2_PORT" "$HY2_EXTERNAL_PORT")"

	if [[ -z "${HY2_DOMAIN:-}" ]]; then
		HY2_DOMAIN="$PUBLIC_HOST"
		HY2_TLS_MODE="self-signed"
		HY2_CERT_FILE="${APP_DATA_DIR}/certs/hy2-selfsigned.crt"
		HY2_KEY_FILE="${APP_DATA_DIR}/certs/hy2-selfsigned.key"
		warn "HY2_DOMAIN is empty; self-signed TLS mode lowers camouflage completeness"
	elif [[ -n "${EMAIL:-}" ]]; then
		HY2_TLS_MODE="acme"
		HY2_CERT_FILE=""
		HY2_KEY_FILE=""
	else
		HY2_TLS_MODE="self-signed"
		HY2_CERT_FILE="${APP_DATA_DIR}/certs/hy2-selfsigned.crt"
		HY2_KEY_FILE="${APP_DATA_DIR}/certs/hy2-selfsigned.key"
		warn "EMAIL is empty; self-signed TLS mode will be used for Hysteria2"
	fi

	HY2_MASQUERADE_DIR="${APP_DATA_DIR}/hy2-site"

	export HY2_DOMAIN HY2_PASSWORD HY2_OBFS_PASSWORD HY2_TLS_MODE HY2_CERT_FILE HY2_KEY_FILE HY2_MASQUERADE_DIR HY2_CLIENT_PORT

	local rendered_config
	rendered_config="${RENDER_DIR}/hysteria-server.yaml"
	render_template "${PROJECT_ROOT}/templates/hysteria-server.yaml.tpl" "$rendered_config"

	if is_dry_run; then
		cp "$rendered_config" "$HY2_CONFIG_FILE"
		write_hy2_client_exports
		log "dry-run: rendered Hysteria2 config; UDP availability is not assumed"
		credentials_notice
		return 0
	fi

	install_hysteria2_core
	ensure_hy2_self_signed_cert
	warn_udp_port_state "$(effective_export_port "$HY2_PORT" "$HY2_EXTERNAL_PORT")"
	allow_firewall_port "$(effective_export_port "$HY2_PORT" "$HY2_EXTERNAL_PORT")" udp
	stage_hy2_config_with_rollback "$rendered_config"
	write_hy2_client_exports
	credentials_notice
}
