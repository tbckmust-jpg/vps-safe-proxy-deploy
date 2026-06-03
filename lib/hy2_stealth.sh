#!/usr/bin/env bash

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
		warn "HY2_DOMAIN is empty; dry-run renders self-signed TLS mode and camouflage completeness is lower"
	elif [[ -n "${EMAIL:-}" ]]; then
		HY2_TLS_MODE="acme"
		HY2_CERT_FILE=""
		HY2_KEY_FILE=""
	else
		HY2_TLS_MODE="self-signed"
		HY2_CERT_FILE="${APP_DATA_DIR}/certs/hy2-selfsigned.crt"
		HY2_KEY_FILE="${APP_DATA_DIR}/certs/hy2-selfsigned.key"
		warn "EMAIL is empty; dry-run renders self-signed TLS mode for Hysteria2"
	fi

	HY2_MASQUERADE_DIR="${APP_DATA_DIR}/hy2-site"

	export HY2_DOMAIN HY2_PASSWORD HY2_OBFS_PASSWORD HY2_TLS_MODE HY2_CERT_FILE HY2_KEY_FILE HY2_MASQUERADE_DIR HY2_CLIENT_PORT

	render_template "${PROJECT_ROOT}/templates/hysteria-server.yaml.tpl" "$HY2_CONFIG_FILE"
	write_hy2_client_exports

	if is_dry_run; then
		log "dry-run: rendered Hysteria2 config; UDP availability is not assumed"
		credentials_notice
		return 0
	fi

	allow_firewall_port "$HY2_PORT" udp
	die "Hysteria2 installation is not implemented in this first skeleton step"
}
