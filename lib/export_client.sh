#!/usr/bin/env bash

effective_export_port() {
	local listen_port="$1"
	local external_port="$2"

	if is_true "${NAT_MODE:-false}" && [[ -n "$external_port" ]]; then
		printf '%s\n' "$external_port"
	else
		printf '%s\n' "$listen_port"
	fi
}

write_reality_client_exports() {
	local export_port scheme
	export_port="$(effective_export_port "$REALITY_PORT" "$REALITY_EXTERNAL_PORT")"
	scheme="vless"

	remove_credential_section "reality-vision"
	append_credential ''
	append_credential '[reality-vision]'
	append_credential "uuid=${REALITY_UUID}"
	append_credential "public_key=${REALITY_PUBLIC_KEY}"
	append_credential "short_id=${REALITY_SHORT_ID}"
	append_credential "v2rayN=${scheme}://${REALITY_UUID}@${PUBLIC_HOST}:${export_port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${REALITY_SERVER_NAME}&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}&type=tcp#Reality-Vision"
	append_credential "sing_box_outbound={\"type\":\"vless\",\"tag\":\"reality-vision\",\"server\":\"${PUBLIC_HOST}\",\"server_port\":${export_port},\"uuid\":\"${REALITY_UUID}\",\"flow\":\"xtls-rprx-vision\",\"tls\":{\"enabled\":true,\"server_name\":\"${REALITY_SERVER_NAME}\",\"utls\":{\"enabled\":true,\"fingerprint\":\"chrome\"},\"reality\":{\"enabled\":true,\"public_key\":\"${REALITY_PUBLIC_KEY}\",\"short_id\":\"${REALITY_SHORT_ID}\"}}}"
}

write_hy2_client_exports() {
	local export_port scheme scheme_alias client_file encoded_password encoded_obfs encoded_sni encoded_pin insecure_param pin_param v2rayn_xray_param tls_json
	export_port="${HY2_CLIENT_PORT:-$(effective_export_port "$HY2_PORT" "$HY2_EXTERNAL_PORT")}"
	scheme="hysteria2"
	scheme_alias="hy2"
	client_file="$HY2_CLIENT_CONFIG_FILE"
	encoded_password="$(url_encode "$HY2_PASSWORD")"
	encoded_obfs="$(url_encode "$HY2_OBFS_PASSWORD")"
	encoded_sni="$(url_encode "$HY2_DOMAIN")"
	encoded_pin="$(url_encode "${HY2_CERT_SHA256:-}")"
	insecure_param=""
	pin_param=""
	v2rayn_xray_param=""

	if [[ "${HY2_TLS_MODE:-}" == "self-signed" ]]; then
		HY2_TLS_INSECURE=true
		insecure_param="&insecure=1"
		pin_param="&pinSHA256=${encoded_pin}"
		v2rayn_xray_param="&pcs=${encoded_pin}&vcn=0"
		tls_json="\"tls\":{\"enabled\":true,\"server_name\":\"${HY2_DOMAIN}\",\"insecure\":true}"
	else
		HY2_TLS_INSECURE=false
		tls_json="\"tls\":{\"enabled\":true,\"server_name\":\"${HY2_DOMAIN}\"}"
	fi
	export HY2_TLS_INSECURE

	render_template "${PROJECT_ROOT}/templates/hysteria-client.yaml.tpl" "$client_file"

	remove_credential_section "hysteria2"
	append_credential ''
	append_credential '[hysteria2]'
	append_credential "password=${HY2_PASSWORD}"
	append_credential "client_yaml=${client_file}"
	append_credential "v2rayN_hint=If URI import fails, use sing-box core or import the client yaml / sing-box outbound."
	if [[ "${HY2_TLS_MODE:-}" == "self-signed" ]]; then
		append_credential "note=self-signed mode, client must allow insecure certificate verification"
		append_credential "cert_pin_sha256=${HY2_CERT_SHA256}"
	fi
	append_credential "uri=${scheme}://${encoded_password}@${PUBLIC_HOST}:${export_port}/?sni=${encoded_sni}&obfs=salamander&obfs-password=${encoded_obfs}${insecure_param}${pin_param}#Hysteria2-Stealth"
	append_credential "hy2_uri=${scheme_alias}://${encoded_password}@${PUBLIC_HOST}:${export_port}/?sni=${encoded_sni}&obfs=salamander&obfs-password=${encoded_obfs}${insecure_param}${pin_param}#Hysteria2-Stealth"
	if [[ "${HY2_TLS_MODE:-}" == "self-signed" ]]; then
		append_credential "v2rayN_xray_uri=${scheme}://${encoded_password}@${PUBLIC_HOST}:${export_port}/?sni=${encoded_sni}&obfs=salamander&obfs-password=${encoded_obfs}${v2rayn_xray_param}#Hysteria2-Stealth-Xray"
	fi
	append_credential "sing_box_outbound={\"type\":\"hysteria2\",\"tag\":\"hysteria2-stealth\",\"server\":\"${PUBLIC_HOST}\",\"server_port\":${export_port},\"password\":\"${HY2_PASSWORD}\",${tls_json},\"obfs\":{\"type\":\"salamander\",\"password\":\"${HY2_OBFS_PASSWORD}\"}}"
}

write_xhttp_client_exports() {
	local export_port scheme host_header security query tls_json
	export_port="$(effective_export_port "$XHTTP_HTTPS_PORT" "$XHTTP_EXTERNAL_PORT")"
	scheme="vless"
	host_header="${XHTTP_DOMAIN}"

	if is_true "${XHTTP_HAS_DOMAIN:-false}"; then
		security="tls"
		query="encryption=none&security=${security}&type=xhttp&host=${host_header}&path=${XHTTP_PATH}&sni=${XHTTP_DOMAIN}"
		tls_json="\"tls\":{\"enabled\":true,\"server_name\":\"${XHTTP_DOMAIN}\"}"
	else
		security="none"
		host_header="${PUBLIC_HOST}"
		query="encryption=none&security=${security}&type=xhttp&host=${host_header}&path=${XHTTP_PATH}"
		tls_json="\"tls\":{\"enabled\":false}"
	fi

	remove_credential_section "xhttp-cdn"
	append_credential ''
	append_credential '[xhttp-cdn]'
	append_credential "uuid=${XHTTP_UUID}"
	append_credential "path=${XHTTP_PATH}"
	if ! is_true "${XHTTP_HAS_DOMAIN:-false}"; then
		append_credential "note=no-domain downgrade mode; TLS camouflage completeness is lower"
	fi
	append_credential "v2rayN=${scheme}://${XHTTP_UUID}@${PUBLIC_HOST}:${export_port}?${query}#XHTTP-CDN"
	append_credential "sing_box_outbound={\"type\":\"vless\",\"tag\":\"xhttp-cdn\",\"server\":\"${PUBLIC_HOST}\",\"server_port\":${export_port},\"uuid\":\"${XHTTP_UUID}\",${tls_json},\"transport\":{\"type\":\"xhttp\",\"path\":\"${XHTTP_PATH}\",\"headers\":{\"Host\":\"${host_header}\"}}}"
}
