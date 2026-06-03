#!/usr/bin/env bash

install_reality_vision() {
	ensure_no_port_conflicts
	prepare_runtime_dirs

	REALITY_UUID="${REALITY_UUID:-$(random_uuid)}"
	REALITY_SHORT_ID="${REALITY_SHORT_ID:-$(random_hex 8)}"

	if ! is_dry_run; then
		install_xray_core
	fi

	generate_reality_keypair
	export REALITY_UUID REALITY_PRIVATE_KEY REALITY_PUBLIC_KEY REALITY_SHORT_ID

	local rendered_config
	rendered_config="${RENDER_DIR}/xray-reality-vision.json"
	render_template "${PROJECT_ROOT}/templates/xray-reality-vision.json.tpl" "$rendered_config"

	if is_dry_run; then
		cp "$rendered_config" "$XRAY_REALITY_CONFIG_FILE"
		write_reality_client_exports
		log "dry-run: rendered Reality Vision config"
		credentials_notice
		return 0
	fi

	allow_firewall_port "$(effective_export_port "$REALITY_PORT" "$REALITY_EXTERNAL_PORT")" tcp
	stage_xray_config_with_rollback "$rendered_config" "$XRAY_REALITY_CONFIG_FILE" xray
	write_reality_client_exports
	credentials_notice
}
