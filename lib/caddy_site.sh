#!/usr/bin/env bash

render_caddy_site() {
	CADDY_TLS_LINE=""

	if [[ -n "${EMAIL:-}" ]]; then
		CADDY_TLS_LINE="tls ${EMAIL}"
	fi
	export CADDY_TLS_LINE

	mkdir -p "$CADDY_SITE_DIR"
	render_template "${PROJECT_ROOT}/templates/fake-site-index.html.tpl" "${CADDY_SITE_DIR}/index.html"
	render_template "${PROJECT_ROOT}/templates/Caddyfile.tpl" "$CADDY_CONFIG_FILE"
}
