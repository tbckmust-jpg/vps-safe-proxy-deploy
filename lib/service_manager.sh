#!/usr/bin/env bash

require_systemd_service_manager() {
	detect_platform
	if [[ "${SERVICE_MANAGER:-unknown}" != "systemd" ]]; then
		die "systemd service manager is required for real installation; detected ${SERVICE_MANAGER:-unknown}"
	fi
}

service_daemon_reload() {
	if is_dry_run; then
		log "dry-run: would reload service manager"
		return 0
	fi

	require_systemd_service_manager
	systemctl daemon-reload
}

service_enable() {
	local service="$1"

	if is_dry_run; then
		log "dry-run: would enable ${service}"
		return 0
	fi

	require_systemd_service_manager
	systemctl enable "$service"
}

service_restart() {
	local service="$1"

	if is_dry_run; then
		log "dry-run: would restart ${service}"
		return 0
	fi

	require_systemd_service_manager
	systemctl restart "$service"
}

service_disable_now() {
	local service="$1"

	if is_dry_run; then
		log "dry-run: would disable and stop ${service}"
		return 0
	fi

	if [[ "${SERVICE_MANAGER:-}" != "systemd" ]]; then
		detect_platform
	fi

	if [[ "${SERVICE_MANAGER:-unknown}" != "systemd" ]]; then
		warn "systemd not available; cannot disable ${service}"
		return 0
	fi

	systemctl disable --now "$service"
}

service_status() {
	local service="$1"

	if [[ "${SERVICE_MANAGER:-}" != "systemd" ]]; then
		detect_platform
	fi

	if [[ "${SERVICE_MANAGER:-unknown}" == "systemd" ]] && command -v systemctl >/dev/null 2>&1; then
		systemctl --no-pager --full status "$service" || true
	else
		warn "systemd not available; cannot query ${service}"
	fi
}
