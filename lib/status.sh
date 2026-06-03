#!/usr/bin/env bash

show_status() {
	if is_dry_run; then
		log "dry-run: would query xray, hysteria-server, and caddy"
		return 0
	fi

	log "credentials file: ${CREDENTIALS_FILE}"

	for service in xray hysteria-server caddy; do
		if command -v systemctl >/dev/null 2>&1; then
			systemctl --no-pager --full status "$service" || true
		else
			warn "systemctl not found; cannot query ${service}"
		fi
	done

	if command -v ss >/dev/null 2>&1; then
		ss -tulpen | grep -E ":(${REALITY_PORT}|${HY2_PORT}|${XHTTP_HTTPS_PORT}|${XHTTP_INTERNAL_PORT})[[:space:]]" || true
	else
		warn "ss not found; cannot display listening ports"
	fi
}
