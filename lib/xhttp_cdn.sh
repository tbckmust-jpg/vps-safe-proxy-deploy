#!/usr/bin/env bash

install_xhttp_cdn() {
	ensure_no_port_conflicts
	prepare_runtime_dirs

	XHTTP_DOMAIN="${XHTTP_DOMAIN:-${PUBLIC_HOST}}"
	XHTTP_UUID="${XHTTP_UUID:-$(random_uuid)}"
	XHTTP_PATH="${XHTTP_PATH:-/assets/$(random_hex 8)}"
	export XHTTP_DOMAIN XHTTP_UUID XHTTP_PATH

	if [[ "$XHTTP_INTERNAL_HOST" != "127.0.0.1" ]]; then
		die "XHTTP_INTERNAL_HOST must be 127.0.0.1 so Xray XHTTP is not exposed publicly"
	fi

	render_template "${PROJECT_ROOT}/templates/xray-xhttp.json.tpl" "$XRAY_XHTTP_CONFIG_FILE"
	render_caddy_site
	write_xhttp_client_exports

	if is_dry_run; then
		log "dry-run: rendered XHTTP/Caddy config"
		credentials_notice
		return 0
	fi

	install_xray_core
	allow_firewall_port "$XHTTP_HTTPS_PORT" tcp
	die "XHTTP/Caddy installation is not implemented in this first skeleton step"
}
