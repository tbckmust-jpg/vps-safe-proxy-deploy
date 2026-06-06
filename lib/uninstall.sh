#!/usr/bin/env bash

remove_project_configs() {
	rm -f "$XRAY_REALITY_CONFIG_FILE" "$XRAY_XHTTP_CONFIG_FILE" "$HY2_CONFIG_FILE" "$CADDY_CONFIG_FILE"
	rm -f "$HY2_CLIENT_CONFIG_FILE" "$CADDY_RENDERED_CONFIG_FILE"
}

uninstall_all() {
	prepare_runtime_dirs

	if is_dry_run; then
		log "dry-run: would stop and disable services, remove project configs, and preserve ${CREDENTIALS_FILE}"
		if is_true "${PURGE:-false}"; then
			log "dry-run: --purge would also remove credentials and credential backups"
		fi
		return 0
	fi

	detect_platform
	for service in xray hysteria-server caddy; do
		service_disable_now "$service" || true
	done

	remove_project_configs
	log "project configs removed; credentials backups preserved"

	if is_true "${PURGE:-false}"; then
		rm -f "$CREDENTIALS_FILE"
		rm -rf "$BACKUP_DIR"
		log "credentials and credential backups removed by --purge"
	else
		log "credentials preserved at ${CREDENTIALS_FILE}; pass --purge to remove them"
	fi
}
