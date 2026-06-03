#!/usr/bin/env bash

install_caddy() {
	if is_dry_run; then
		log "dry-run: would install Caddy"
		return 0
	fi

	require_linux_install_host

	if is_test_mode; then
		log "test-mode: skipping Caddy package installation and using mock caddy"
		caddy version >/dev/null 2>&1 || true
		return 0
	fi

	install_system_dependencies
	apt-get install -y debian-keyring debian-archive-keyring apt-transport-https gpg
	curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key -o /tmp/caddy-stable-gpg.key
	gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg /tmp/caddy-stable-gpg.key
	curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt -o /etc/apt/sources.list.d/caddy-stable.list
	apt-get update
	apt-get install -y caddy
}

render_caddy_site() {
	local target="${1:-$CADDY_CONFIG_FILE}"

	CADDY_TLS_LINE=""
	CADDY_SITE_NAME="${XHTTP_DOMAIN:-${PUBLIC_HOST}}"

	if [[ -n "${EMAIL:-}" ]]; then
		CADDY_TLS_LINE="tls ${EMAIL}"
	fi
	export CADDY_TLS_LINE

	if is_true "${XHTTP_HAS_DOMAIN:-false}"; then
		CADDY_SITE_ADDRESS="${XHTTP_DOMAIN}:${XHTTP_HTTPS_PORT}"
	else
		CADDY_SITE_ADDRESS=":${XHTTP_HTTPS_PORT}"
		CADDY_TLS_LINE=""
		warn "XHTTP_DOMAIN is empty; Caddy will render no-domain downgrade mode and camouflage completeness is lower"
	fi
	export CADDY_SITE_ADDRESS CADDY_SITE_NAME CADDY_TLS_LINE

	mkdir -p "$CADDY_SITE_DIR"
	render_template "${PROJECT_ROOT}/templates/fake-site-index.html.tpl" "${CADDY_SITE_DIR}/index.html"
	render_template "${PROJECT_ROOT}/templates/Caddyfile.tpl" "$target"
}

stage_caddy_config_with_rollback() {
	local rendered="$1"
	local backup_path

	backup_path="$(install_with_backup "$rendered" "$CADDY_CONFIG_FILE" caddy)"

	if ! caddy validate --config "$CADDY_CONFIG_FILE"; then
		warn "caddy validate failed; restoring previous Caddyfile"
		rollback_config "$backup_path" "$CADDY_CONFIG_FILE"
		return 1
	fi

	if ! systemctl restart caddy; then
		warn "systemctl restart caddy failed; restoring previous Caddyfile"
		rollback_config "$backup_path" "$CADDY_CONFIG_FILE"
		return 1
	fi
}
