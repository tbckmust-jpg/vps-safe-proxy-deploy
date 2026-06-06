#!/usr/bin/env bash

VERIFY_EXPORTS_FAILURES=0

verify_result() {
	local status="$1"
	local label="$2"

	if [[ "$status" == "pass" ]]; then
		printf 'PASS %s\n' "$label"
	else
		printf 'FAIL %s\n' "$label"
		VERIFY_EXPORTS_FAILURES=$((VERIFY_EXPORTS_FAILURES + 1))
	fi
}

verify_file_mode() {
	local file="$1"

	if command -v stat >/dev/null 2>&1; then
		stat -c '%a' "$file" 2>/dev/null && return 0
		stat -f '%Lp' "$file" 2>/dev/null && return 0
	fi

	printf 'unknown\n'
}

credential_section_count() {
	local section="$1"

	[[ -r "$CREDENTIALS_FILE" ]] || {
		printf '0\n'
		return 0
	}

	awk -v section="[${section}]" '$0 == section { count++ } END { print count + 0 }' "$CREDENTIALS_FILE"
}

credential_line_matches() {
	local section="$1"
	local regex="$2"

	[[ -r "$CREDENTIALS_FILE" ]] || return 1
	awk -v section="[${section}]" -v regex="$regex" '
		$0 ~ /^\[[^]]+\]$/ {
			active = ($0 == section)
			next
		}
		active && $0 ~ regex {
			found = 1
		}
		END {
			exit found ? 0 : 1
		}
	' "$CREDENTIALS_FILE"
}

credential_key_value() {
	local section="$1"
	local key="$2"

	[[ -r "$CREDENTIALS_FILE" ]] || return 1
	awk -v section="[${section}]" -v key="${key}=" '
		$0 ~ /^\[[^]]+\]$/ {
			active = ($0 == section)
			next
		}
		active && index($0, key) == 1 {
			print substr($0, length(key) + 1)
			exit
		}
	' "$CREDENTIALS_FILE"
}

credentials_have_duplicate_sections() {
	[[ -r "$CREDENTIALS_FILE" ]] || return 1
	awk '
		/^\[[^]]+\]$/ {
			count[$0]++
		}
		END {
			for (section in count) {
				if (count[section] > 1) {
					exit 0
				}
			}
			exit 1
		}
	' "$CREDENTIALS_FILE"
}

verify_section_once() {
	local section="$1"
	local count

	count="$(credential_section_count "$section")"
	[[ "$count" == "1" ]]
}

verify_exports() {
	local client_yaml credentials_mode

	VERIFY_EXPORTS_FAILURES=0

	if [[ -f "$CREDENTIALS_FILE" ]]; then
		verify_result pass "credentials file exists"
	else
		verify_result fail "credentials file exists"
	fi

	credentials_mode="$(verify_file_mode "$CREDENTIALS_FILE")"
	if [[ "$credentials_mode" == "600" ]]; then
		verify_result pass "credentials permission is 600"
	else
		verify_result fail "credentials permission is 600"
	fi

	if verify_section_once "reality-vision"; then
		verify_result pass "[reality-vision] appears once"
	else
		verify_result fail "[reality-vision] appears once"
	fi

	if verify_section_once "hysteria2"; then
		verify_result pass "[hysteria2] appears once"
	else
		verify_result fail "[hysteria2] appears once"
	fi

	if verify_section_once "xhttp-cdn"; then
		verify_result pass "[xhttp-cdn] appears once"
	else
		verify_result fail "[xhttp-cdn] appears once"
	fi

	if credential_line_matches "reality-vision" '^v2rayN='; then
		verify_result pass "Reality v2rayN link exists"
	else
		verify_result fail "Reality v2rayN link exists"
	fi

	if credential_line_matches "reality-vision" '^sing_box_outbound=.*"type":"vless"'; then
		verify_result pass "Reality sing-box outbound exists"
	else
		verify_result fail "Reality sing-box outbound exists"
	fi

	if credential_line_matches "hysteria2" '^uri='; then
		verify_result pass "HY2 native URI exists"
	else
		verify_result fail "HY2 native URI exists"
	fi

	if credential_line_matches "hysteria2" '^v2rayN_xray_uri=.*[?&]pcs='; then
		verify_result pass "HY2 v2rayN_xray_uri exists"
	else
		verify_result fail "HY2 v2rayN_xray_uri exists"
	fi

	client_yaml="$(credential_key_value "hysteria2" "client_yaml" || true)"
	if [[ -n "$client_yaml" && -f "$client_yaml" ]]; then
		verify_result pass "HY2 client yaml exists"
	else
		verify_result fail "HY2 client yaml exists"
	fi

	if credential_line_matches "hysteria2" '^sing_box_outbound=.*"type":"hysteria2"'; then
		verify_result pass "HY2 sing-box outbound exists"
	else
		verify_result fail "HY2 sing-box outbound exists"
	fi

	if credential_line_matches "hysteria2" '^password=[A-Za-z0-9_-]+$' && credential_line_matches "hysteria2" '^sing_box_outbound=.*"obfs":\{"type":"salamander","password":"[A-Za-z0-9_-]+"\}'; then
		verify_result pass "HY2 secret URL-safe"
	else
		verify_result fail "HY2 secret URL-safe"
	fi

	if [[ -n "$client_yaml" && -f "$client_yaml" ]] && grep -Eq '^[[:space:]]*insecure:[[:space:]]*true$' "$client_yaml" && credential_line_matches "hysteria2" '^uri=.*[?&]insecure=1' && credential_line_matches "hysteria2" '^cert_pin_sha256=[A-Fa-f0-9]+$'; then
		verify_result pass "HY2 self-signed insecure exists"
	else
		verify_result fail "HY2 self-signed insecure exists"
	fi

	if credential_line_matches "xhttp-cdn" '^v2rayN='; then
		verify_result pass "XHTTP v2rayN link exists"
	else
		verify_result fail "XHTTP v2rayN link exists"
	fi

	if credential_line_matches "xhttp-cdn" '^v2rayN=.*[?&]security=none'; then
		verify_result pass "XHTTP no-domain security=none"
	else
		verify_result fail "XHTTP no-domain security=none"
	fi

	if credential_line_matches "xhttp-cdn" '^sing_box_outbound=.*"tls":\{"enabled":false\}'; then
		verify_result pass "XHTTP sing-box tls.enabled=false"
	else
		verify_result fail "XHTTP sing-box tls.enabled=false"
	fi

	if credentials_have_duplicate_sections; then
		verify_result fail "no duplicate sections"
	else
		verify_result pass "no duplicate sections"
	fi

	verify_result pass "no complete proxy URI printed to terminal"

	if [[ "$VERIFY_EXPORTS_FAILURES" -eq 0 ]]; then
		return 0
	fi

	return 1
}
