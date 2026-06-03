#!/usr/bin/env bash

detect_command_status() {
	if command -v "$1" >/dev/null 2>&1; then
		printf 'present\n'
	else
		printf 'missing\n'
	fi
}

detect_load_os_info() {
	local os_release_file="${OS_RELEASE_FILE:-/etc/os-release}"
	local ID=""
	local NAME=""
	local PRETTY_NAME=""
	local VERSION_ID=""

	DETECT_OS_ID="unknown"
	DETECT_OS_NAME="unknown"
	DETECT_OS_PRETTY="unknown"
	DETECT_OS_VERSION="unknown"

	if [[ -r "$os_release_file" ]]; then
		# shellcheck source=/dev/null
		. "$os_release_file"
		DETECT_OS_ID="${ID:-unknown}"
		DETECT_OS_NAME="${NAME:-unknown}"
		DETECT_OS_PRETTY="${PRETTY_NAME:-${NAME:-unknown} ${VERSION_ID:-unknown}}"
		DETECT_OS_VERSION="${VERSION_ID:-unknown}"
	fi
}

detect_supported_release() {
	case "${DETECT_OS_ID:-unknown}:${DETECT_OS_VERSION:-unknown}" in
	debian:11 | debian:12 | ubuntu:22.04 | ubuntu:24.04) return 0 ;;
	*) return 1 ;;
	esac
}

detect_init_system_name() {
	if [[ -n "${DETECT_INIT_SYSTEM:-}" ]]; then
		printf '%s\n' "$DETECT_INIT_SYSTEM"
		return 0
	fi

	if [[ -d /run/systemd/system ]]; then
		printf 'systemd\n'
		return 0
	fi

	if [[ -d /run/openrc ]] || command -v rc-service >/dev/null 2>&1; then
		printf 'OpenRC\n'
		return 0
	fi

	if [[ -r /proc/1/comm ]]; then
		case "$(cat /proc/1/comm 2>/dev/null || true)" in
		systemd) printf 'systemd\n' && return 0 ;;
		openrc* | init) printf 'OpenRC\n' && return 0 ;;
		esac
	fi

	printf 'unknown\n'
}

detect_root_status() {
	if [[ -n "${DETECT_IS_ROOT:-}" ]]; then
		if is_true "$DETECT_IS_ROOT"; then
			printf 'yes\n'
		else
			printf 'no\n'
		fi
		return 0
	fi

	if [[ "$(id -u 2>/dev/null || printf '1')" == "0" ]]; then
		printf 'yes\n'
	else
		printf 'no\n'
	fi
}

detect_virtualization_type() {
	local product_name=""

	if [[ -n "${DETECT_VIRT:-}" ]]; then
		printf '%s\n' "$DETECT_VIRT"
		return 0
	fi

	if [[ -f /.dockerenv ]]; then
		printf 'Docker\n'
		return 0
	fi

	if [[ -r /proc/1/cgroup ]]; then
		if grep -Eiq '(^|/)(lxc|libpod-lxc)(/|$)' /proc/1/cgroup; then
			printf 'LXC\n'
			return 0
		fi
		if grep -Eiq '(docker|containerd|kubepods|libpod)' /proc/1/cgroup; then
			printf 'Docker\n'
			return 0
		fi
	fi

	if [[ -r /sys/class/dmi/id/product_name ]]; then
		product_name="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
		if [[ "$product_name" == *KVM* || "$product_name" == *QEMU* ]]; then
			printf 'KVM\n'
			return 0
		fi
	fi

	printf 'unknown\n'
}

detect_systemd_support() {
	local init_system="$1"

	if [[ "$init_system" == "systemd" ]] && command -v systemctl >/dev/null 2>&1; then
		printf 'yes\n'
	else
		printf 'no\n'
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

detect_bbr_status() {
	local virt="$1"

	if [[ -n "${DETECT_BBR_STATUS:-}" ]]; then
		printf '%s\n' "$DETECT_BBR_STATUS"
		return 0
	fi

	case "$virt" in
	LXC | Docker | lxc | docker)
		printf 'unsupported in container\n'
		return 0
		;;
	esac

	if [[ "$(uname -s 2>/dev/null || true)" != "Linux" ]]; then
		printf 'unknown\n'
		return 0
	fi

	if [[ -r /proc/sys/net/ipv4/tcp_available_congestion_control ]]; then
		if grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control; then
			printf 'supported\n'
		else
			printf 'unknown\n'
		fi
		return 0
	fi

	if command -v sysctl >/dev/null 2>&1; then
		if sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr; then
			printf 'supported\n'
		else
			printf 'unknown\n'
		fi
		return 0
	fi

	printf 'unknown\n'
}

detect_base_install_status() {
	local init_system="$1"
	local is_root="$2"
	local systemd_supported="$3"

	if detect_supported_release && [[ "$init_system" == "systemd" && "$systemd_supported" == "yes" && "$is_root" == "yes" ]]; then
		printf 'full install supported\n'
		return 0
	fi

	case "${DETECT_OS_ID:-unknown}" in
	alpine)
		printf 'dry-run only\n'
		return 0
		;;
	unknown)
		printf 'unsupported\n'
		return 0
		;;
	esac

	if ! detect_supported_release; then
		printf 'unsupported\n'
	elif [[ "$init_system" != "systemd" || "$systemd_supported" != "yes" || "$is_root" != "yes" ]]; then
		printf 'dry-run only\n'
	else
		printf 'unsupported\n'
	fi
}

detect_reality_status() {
	local base_status="$1"
	local tcp443_status="$2"

	if [[ "$base_status" != "full install supported" ]]; then
		printf '%s\n' "$base_status"
	elif [[ "$tcp443_status" == "occupied" ]]; then
		printf 'unsupported\n'
	else
		printf 'full install supported\n'
	fi
}

detect_hy2_status() {
	local base_status="$1"
	local udp8443_status="$2"

	if ! should_install_hy2; then
		printf 'skipped because INSTALL_HY2=false\n'
	elif [[ "$base_status" != "full install supported" ]]; then
		printf 'dry-run only\n'
	elif is_true "${NAT_MODE:-false}" && ! is_true "${HY2_UDP_MAPPED:-false}"; then
		printf 'unavailable because UDP is not mapped / unknown\n'
	elif [[ "$udp8443_status" == local\ socket\ occupied* ]]; then
		printf 'unavailable because UDP is not mapped / unknown\n'
	else
		printf 'full install supported\n'
	fi
}

detect_xhttp_status() {
	local base_status="$1"
	local tcp2053_status="$2"

	if [[ "$base_status" != "full install supported" ]]; then
		printf '%s\n' "$base_status"
	elif [[ "$tcp2053_status" == "occupied" ]]; then
		printf 'unsupported\n'
	else
		printf 'full install supported\n'
	fi
}

show_detect_matrix() {
	local init_system is_root virt arch systemd_supported bbr_status
	local tcp443_status tcp2053_status udp8443_status public_host_result base_status

	detect_load_os_info
	init_system="$(detect_init_system_name)"
	is_root="$(detect_root_status)"
	virt="$(detect_virtualization_type)"
	arch="$(uname -m 2>/dev/null || printf 'unknown')"
	systemd_supported="$(detect_systemd_support "$init_system")"
	bbr_status="$(detect_bbr_status "$virt")"
	tcp443_status="$(detect_tcp_port_status 443)"
	tcp2053_status="$(detect_tcp_port_status 2053)"
	udp8443_status="$(detect_udp_port_status 8443)"
	public_host_result="$(detect_public_host_for_matrix)"
	base_status="$(detect_base_install_status "$init_system" "$is_root" "$systemd_supported")"

	cat <<EOF
Capability Matrix
OS: ${DETECT_OS_PRETTY}
OS name: ${DETECT_OS_NAME}
OS version: ${DETECT_OS_VERSION}
Init system: ${init_system}
Root: ${is_root}
Virtualization: ${virt}
Architecture: ${arch}
Systemd supported: ${systemd_supported}
BBR possible: ${bbr_status}
curl: $(detect_command_status curl)
unzip: $(detect_command_status unzip)
openssl: $(detect_command_status openssl)
TCP 443: ${tcp443_status}
TCP 2053: ${tcp2053_status}
UDP 8443: ${udp8443_status}
NAT_MODE: ${NAT_MODE}
PUBLIC_HOST: ${public_host_result}

Scheme Status
Reality Vision: $(detect_reality_status "$base_status" "$tcp443_status")
Hysteria2: $(detect_hy2_status "$base_status" "$udp8443_status")
XHTTP + Caddy: $(detect_xhttp_status "$base_status" "$tcp2053_status")
BBR: ${bbr_status}
EOF
}
