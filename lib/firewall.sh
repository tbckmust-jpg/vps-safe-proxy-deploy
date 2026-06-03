#!/usr/bin/env bash

allow_firewall_port() {
	local port="$1"
	local proto="$2"

	if ! is_true "${ENABLE_FIREWALL:-true}"; then
		log "firewall changes disabled by configuration"
		return 0
	fi

	if is_dry_run; then
		log "dry-run: would allow ${port}/${proto}"
		return 0
	fi

	if command -v ufw >/dev/null 2>&1; then
		ufw allow "${port}/${proto}"
	else
		warn "ufw not found; please allow ${port}/${proto} manually"
	fi
}
