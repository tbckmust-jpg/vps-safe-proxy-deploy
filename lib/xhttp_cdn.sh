#!/usr/bin/env bash

validate_xhttp_runtime() {
	if ! tcp_port_listening "$XHTTP_INTERNAL_HOST" "$XHTTP_INTERNAL_PORT"; then
		warn "Xray XHTTP is not listening on ${XHTTP_INTERNAL_HOST}:${XHTTP_INTERNAL_PORT}"
		return 1
	fi
}

install_xhttp_cdn() {
	ensure_no_port_conflicts
	prepare_runtime_dirs

	if [[ -n "${XHTTP_DOMAIN:-}" ]]; then
		XHTTP_HAS_DOMAIN=true
	else
		XHTTP_HAS_DOMAIN=false
		XHTTP_DOMAIN="${PUBLIC_HOST}"
	fi

	XHTTP_UUID="${XHTTP_UUID:-$(random_uuid)}"
	XHTTP_PATH="${XHTTP_PATH:-/assets/$(random_hex 8)}"
	export XHTTP_DOMAIN XHTTP_HAS_DOMAIN XHTTP_UUID XHTTP_PATH

	if [[ "$XHTTP_INTERNAL_HOST" != "127.0.0.1" ]]; then
		die "XHTTP_INTERNAL_HOST must be 127.0.0.1 so Xray XHTTP is not exposed publicly"
	fi

	local rendered_xray_config
	rendered_xray_config="${RENDER_DIR}/xray-xhttp.json"
	render_template "${PROJECT_ROOT}/templates/xray-xhttp.json.tpl" "$rendered_xray_config"
	render_caddy_site "$CADDY_RENDERED_CONFIG_FILE"

	if is_dry_run; then
		cp "$rendered_xray_config" "$XRAY_XHTTP_CONFIG_FILE"
		cp "$CADDY_RENDERED_CONFIG_FILE" "$CADDY_CONFIG_FILE"
		write_xhttp_client_exports
		log "dry-run: rendered XHTTP/Caddy config"
		credentials_notice
		return 0
	fi

	install_xray_core || return 1
	install_caddy || return 1
	allow_firewall_port "$(effective_export_port "$XHTTP_HTTPS_PORT" "$XHTTP_EXTERNAL_PORT")" tcp
	stage_xray_config_with_rollback "$rendered_xray_config" "$XRAY_XHTTP_CONFIG_FILE" xray || return 1
	stage_caddy_config_with_rollback "$CADDY_RENDERED_CONFIG_FILE" || return 1
	validate_xhttp_runtime || return 1
	write_xhttp_client_exports
	credentials_notice
}
