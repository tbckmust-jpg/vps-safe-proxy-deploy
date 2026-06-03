#!/usr/bin/env bash

uninstall_all() {
	prepare_runtime_dirs

	if is_dry_run; then
		log "dry-run: would stop and disable services, preserving ${CREDENTIALS_FILE}"
		if is_true "${PURGE:-false}"; then
			log "dry-run: --purge would also remove credentials"
		fi
		return 0
	fi

	for service in xray hysteria-server caddy; do
		if command -v systemctl >/dev/null 2>&1; then
			systemctl disable --now "$service" || true
		fi
	done

	if is_true "${PURGE:-false}"; then
		rm -f "$XRAY_REALITY_CONFIG_FILE" "$XRAY_XHTTP_CONFIG_FILE" "$HY2_CONFIG_FILE" "$CADDY_CONFIG_FILE"
		rm -f "$CREDENTIALS_FILE"
	else
		log "credentials preserved at ${CREDENTIALS_FILE}; pass --purge to remove them"
	fi
}
