#!/usr/bin/env bash

show_status() {
	if is_dry_run; then
		log "dry-run: would query xray, hysteria-server, and caddy"
		return 0
	fi

	log "credentials file: ${CREDENTIALS_FILE}"

	detect_platform
	for service in xray hysteria-server caddy; do
		service_status "$service"
	done

	if command -v ss >/dev/null 2>&1; then
		ss -tulpen | grep -E ":(${REALITY_PORT}|${HY2_PORT}|${XHTTP_HTTPS_PORT}|${XHTTP_INTERNAL_PORT})[[:space:]]" || true
	else
		warn "ss not found; cannot display listening ports"
	fi
}
