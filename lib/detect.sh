#!/usr/bin/env bash

detect_dependency_status() {
	local command_name="$1"

	if [[ " ${DETECT_MISSING_COMMANDS:-} " == *" ${command_name} "* ]]; then
		if platform_package_manager_supported; then
			printf 'missing; installable via %s\n' "$PACKAGE_MANAGER"
		else
			printf 'missing; no supported package manager detected\n'
		fi
	elif command -v "$command_name" >/dev/null 2>&1; then
		printf 'present\n'
	elif platform_package_manager_supported; then
		printf 'missing; installable via %s\n' "$PACKAGE_MANAGER"
	else
		printf 'missing; no supported package manager detected\n'
	fi
}

detect_proc_port() {
	local proto="$1"
	local port="$2"
	local hex_port file state
	local -a files
	printf -v hex_port '%04X' "$port"

	if [[ "$proto" == "tcp" ]]; then
		files=(/proc/net/tcp /proc/net/tcp6)
		state="0A"
	else
		files=(/proc/net/udp /proc/net/udp6)
		state=""
	fi

	for file in "${files[@]}"; do
		[[ -r "$file" ]] || continue
		while read -r _ local_address _ remote_state _; do
			[[ "${local_address##*:}" == "$hex_port" ]] || continue
			if [[ "$proto" == "tcp" && "$remote_state" != "$state" ]]; then
				continue
			fi
			return 0
		done <"$file"
	done

	return 1
}

detect_tcp_port_status() {
	local port="$1"
	local override_name="DETECT_TCP_${port}_STATUS"
	local override_value="${!override_name:-}"

	if [[ -n "$override_value" ]]; then
		printf '%s\n' "$override_value"
	elif detect_proc_port tcp "$port"; then
		printf 'occupied\n'
	else
		printf 'free\n'
	fi
}

detect_udp_port_status() {
	local port="$1"
	local override_name="DETECT_UDP_${port}_STATUS"
	local override_value="${!override_name:-}"

	if [[ -n "$override_value" ]]; then
		printf '%s\n' "$override_value"
	elif [[ -r /proc/net/udp || -r /proc/net/udp6 ]]; then
		if detect_proc_port udp "$port"; then
			printf 'local socket occupied; external mapping unknown\n'
		else
			printf 'no local listener; external mapping unknown\n'
		fi
	else
		printf 'unknown\n'
	fi
}

detect_public_host_for_matrix() {
	local detected url

	if [[ -n "${PUBLIC_HOST:-}" ]]; then
		printf '%s (configured)\n' "$PUBLIC_HOST"
		return 0
	fi

	if ! command -v curl >/dev/null 2>&1; then
		printf 'unavailable; set PUBLIC_HOST=1.2.3.4 to override\n'
		return 0
	fi

	for url in \
		"https://api.ipify.org" \
		"https://ifconfig.co" \
		"https://icanhazip.com"; do
		detected="$(curl -4fsS --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]' || true)"
		if is_ipv4 "$detected"; then
			printf '%s (auto-detected)\n' "$detected"
			return 0
		fi
	done

	printf 'unavailable; set PUBLIC_HOST=1.2.3.4 to override\n'
}

detect_bbr_matrix_status() {
	local kernel_status

	kernel_status="$(platform_kernel_bbr_status)"
	if [[ "${IS_CONTAINER:-no}" == "yes" ]]; then
		if [[ "$kernel_status" == "supported" ]]; then
			printf 'kernel supports bbr; applying may be unavailable in container\n'
		else
			printf 'unavailable or unknown in container\n'
		fi
	elif [[ "${SUPPORT_LEVEL:-unsupported}" == "full install candidate" ]]; then
		if [[ "$kernel_status" == "supported" ]]; then
			printf 'supported\n'
		else
			printf 'unsupported\n'
		fi
	else
		printf '%s\n' "$kernel_status"
	fi
}

detect_bbr_scheme_status() {
	local matrix_status="$1"

	if [[ "${IS_CONTAINER:-no}" == "yes" ]]; then
		case "$matrix_status" in
		kernel\ supports\ bbr*)
			printf 'kernel supports bbr; apply permission unknown in container\n'
			;;
		*)
			printf 'unavailable or unknown in container\n'
			;;
		esac
	else
		printf '%s\n' "$matrix_status"
	fi
}

detect_reality_status() {
	local tcp443_status="$1"

	if ! should_install_reality; then
		printf 'skipped because INSTALL_REALITY=false\n'
	elif [[ "${SUPPORT_LEVEL:-unsupported}" != "full install candidate" ]]; then
		printf '%s\n' "${SUPPORT_LEVEL:-unsupported}"
	elif [[ "$tcp443_status" == "occupied" ]]; then
		printf 'unsupported: TCP 443 is occupied\n'
	else
		printf 'full install candidate\n'
	fi
}

detect_hy2_status() {
	local udp8443_status="$1"

	if ! should_install_hy2; then
		printf 'skipped because INSTALL_HY2=false\n'
	elif [[ "${SUPPORT_LEVEL:-unsupported}" != "full install candidate" ]]; then
		printf '%s\n' "${SUPPORT_LEVEL:-unsupported}"
	elif [[ "$udp8443_status" == local\ socket\ occupied* ]]; then
		printf 'unsupported: UDP 8443 appears occupied\n'
	elif is_true "${NAT_MODE:-false}" && ! is_true "${HY2_UDP_MAPPED:-false}"; then
		printf 'full install candidate with UDP warning\n'
	else
		printf 'full install candidate with UDP warning\n'
	fi
}

detect_xhttp_status() {
	local tcp2053_status="$1"

	if ! should_install_xhttp; then
		printf 'skipped because INSTALL_XHTTP=false\n'
	elif [[ "${SUPPORT_LEVEL:-unsupported}" != "full install candidate" ]]; then
		printf '%s\n' "${SUPPORT_LEVEL:-unsupported}"
	elif [[ "$tcp2053_status" == "occupied" ]]; then
		printf 'unsupported: TCP 2053 is occupied\n'
	else
		printf 'full install candidate\n'
	fi
}

show_detect_matrix() {
	local bbr_status bbr_scheme_status public_host_result systemd_supported
	local tcp443_status tcp2053_status udp8443_status

	detect_platform
	if [[ "${SERVICE_MANAGER:-unknown}" == "systemd" ]]; then
		systemd_supported="yes"
	else
		systemd_supported="no"
	fi

	tcp443_status="$(detect_tcp_port_status 443)"
	tcp2053_status="$(detect_tcp_port_status 2053)"
	udp8443_status="$(detect_udp_port_status 8443)"
	public_host_result="$(detect_public_host_for_matrix)"
	bbr_status="$(detect_bbr_matrix_status)"
	bbr_scheme_status="$(detect_bbr_scheme_status "$bbr_status")"

	cat <<EOF
Capability Matrix
OS: ${OS_PRETTY_NAME}
OS ID: ${OS_ID}
OS version: ${OS_VERSION_ID}
OS family: ${OS_FAMILY}
Init system: ${INIT_SYSTEM}
Package manager: ${PACKAGE_MANAGER}
Service manager: ${SERVICE_MANAGER}
Root: ${IS_ROOT}
Virtualization: ${VIRT_TYPE}
Container: ${IS_CONTAINER}
Architecture: ${ARCH}
Systemd supported: ${systemd_supported}
Support level: ${SUPPORT_LEVEL}
Support reason: ${SUPPORT_REASON}
BBR: ${bbr_status}
curl: $(detect_dependency_status curl)
unzip: $(detect_dependency_status unzip)
openssl: $(detect_dependency_status openssl)
TCP 443: ${tcp443_status}
TCP 2053: ${tcp2053_status}
UDP 8443: ${udp8443_status}
NAT_MODE: ${NAT_MODE}
PUBLIC_HOST: ${public_host_result}

Scheme Status
Reality Vision: $(detect_reality_status "$tcp443_status")
Hysteria2: $(detect_hy2_status "$udp8443_status")
XHTTP + Caddy: $(detect_xhttp_status "$tcp2053_status")
BBR: ${bbr_scheme_status}
EOF
}
