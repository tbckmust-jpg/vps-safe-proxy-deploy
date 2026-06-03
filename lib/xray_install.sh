#!/usr/bin/env bash

install_xray_core() {
	if is_dry_run; then
		log "dry-run: would install or update Xray-core"
		return 0
	fi

	die "Xray-core installation is not implemented in this first skeleton step"
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
