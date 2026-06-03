#!/usr/bin/env bash

install_reality_vision() {
	ensure_no_port_conflicts
	prepare_runtime_dirs

	REALITY_UUID="${REALITY_UUID:-$(random_uuid)}"
	REALITY_PRIVATE_KEY="${REALITY_PRIVATE_KEY:-$(random_password)}"
	REALITY_PUBLIC_KEY="${REALITY_PUBLIC_KEY:-$(random_password)}"
	REALITY_SHORT_ID="${REALITY_SHORT_ID:-$(random_hex 8)}"
	export REALITY_UUID REALITY_PRIVATE_KEY REALITY_PUBLIC_KEY REALITY_SHORT_ID

	render_template "${PROJECT_ROOT}/templates/xray-reality-vision.json.tpl" "$XRAY_REALITY_CONFIG_FILE"
	write_reality_client_exports

	if is_dry_run; then
		log "dry-run: rendered Reality Vision config"
		credentials_notice
		return 0
	fi

	install_xray_core
	allow_firewall_port "$REALITY_PORT" tcp
	stage_xray_config_with_rollback "$XRAY_REALITY_CONFIG_FILE" "$XRAY_CONFIG_FILE" xray
	credentials_notice
}
