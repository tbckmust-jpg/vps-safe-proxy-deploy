#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/platform.sh
. "${SCRIPT_DIR}/lib/platform.sh"
# shellcheck source=lib/pkg_manager.sh
. "${SCRIPT_DIR}/lib/pkg_manager.sh"
# shellcheck source=lib/service_manager.sh
. "${SCRIPT_DIR}/lib/service_manager.sh"
# shellcheck source=lib/os_detect.sh
. "${SCRIPT_DIR}/lib/os_detect.sh"
# shellcheck source=lib/bbr.sh
. "${SCRIPT_DIR}/lib/bbr.sh"
# shellcheck source=lib/firewall.sh
. "${SCRIPT_DIR}/lib/firewall.sh"
# shellcheck source=lib/xray_install.sh
. "${SCRIPT_DIR}/lib/xray_install.sh"
# shellcheck source=lib/export_client.sh
. "${SCRIPT_DIR}/lib/export_client.sh"
# shellcheck source=lib/caddy_site.sh
. "${SCRIPT_DIR}/lib/caddy_site.sh"
# shellcheck source=lib/reality_vision.sh
. "${SCRIPT_DIR}/lib/reality_vision.sh"
# shellcheck source=lib/hy2_stealth.sh
. "${SCRIPT_DIR}/lib/hy2_stealth.sh"
# shellcheck source=lib/xhttp_cdn.sh
. "${SCRIPT_DIR}/lib/xhttp_cdn.sh"
# shellcheck source=lib/status.sh
. "${SCRIPT_DIR}/lib/status.sh"
# shellcheck source=lib/uninstall.sh
. "${SCRIPT_DIR}/lib/uninstall.sh"
# shellcheck source=lib/detect.sh
. "${SCRIPT_DIR}/lib/detect.sh"
# shellcheck source=lib/verify_exports.sh
. "${SCRIPT_DIR}/lib/verify_exports.sh"

usage() {
	cat <<'USAGE'
Usage: ./install.sh <command> [--dry-run] [--test-mode] [--purge]

Commands:
	all        Run bbr, reality, hy2, and xhttp
	reality    Render/install VLESS REALITY Vision
	hy2        Render/install Hysteria2 stealth mode
	xhttp      Render/install VLESS XHTTP with Caddy
	bbr        Detect and enable BBR when supported
	detect     Show a read-only platform capability matrix
	status     Show service status
	verify-exports
	           Check generated client exports without printing secrets
	uninstall  Remove installed services; keeps credentials unless --purge
USAGE
}

can_use_tcp_port() {
	local port="$1"
	local label="$2"
	local status

	if is_simulation; then
		return 0
	fi

	status="$(detect_tcp_port_status "$port")"
	if [[ "$status" == managed\ by\ this\ project:* ]]; then
		warn "${label} already appears managed by this project on TCP ${port}"
		return 1
	fi
	if [[ "$status" == "occupied" ]]; then
		warn "${label} skipped: TCP ${port} is already occupied"
		return 1
	fi

	return 0
}

can_use_udp_port() {
	local port="$1"
	local status

	if is_simulation; then
		return 0
	fi

	status="$(detect_udp_port_status "$port")"
	if [[ "$status" == local\ socket\ occupied* ]]; then
		warn "Hysteria2 skipped: UDP ${port} appears occupied locally"
		return 1
	fi

	return 0
}

run_all() {
	local reality_port_status hy2_port_status xhttp_port_status
	local all_failed=0
	ALL_REALITY_STATUS="not run"
	ALL_HY2_STATUS="not run"
	ALL_XHTTP_STATUS="not run"
	ALL_BBR_STATUS="not run"
	ALL_FIREWALL_STATUS="handled during scheme installs"

	detect_supported_os
	log "starting BBR"
	if enable_bbr; then
		ALL_BBR_STATUS="completed"
		log "BBR success"
	else
		ALL_BBR_STATUS="failed"
		warn "BBR failed; continuing with proxy installation"
	fi
	require_public_host
	begin_credentials_regeneration

	if should_install_reality; then
		reality_port_status="$(detect_tcp_port_status "$REALITY_PORT")"
		if [[ "$reality_port_status" == managed\ by\ this\ project:* ]]; then
			log "Reality existing managed install detected; refreshing config and client export"
			if install_reality_vision; then
				ALL_REALITY_STATUS="installed / refreshed managed by this project"
				log "Reality success"
			else
				ALL_REALITY_STATUS="failed"
				all_failed=1
				warn "Reality failed"
			fi
		elif [[ "$reality_port_status" == "occupied" ]] && ! is_simulation; then
			ALL_REALITY_STATUS="skipped: TCP ${REALITY_PORT} conflict"
			all_failed=1
			warn "Reality skipped: TCP ${REALITY_PORT} is occupied by an unknown process"
		else
			log "starting Reality"
			if install_reality_vision; then
				ALL_REALITY_STATUS="installed"
				log "Reality success"
			else
				ALL_REALITY_STATUS="failed"
				all_failed=1
				warn "Reality failed"
			fi
		fi
	else
		write_reality_skipped_notice
		ALL_REALITY_STATUS="skipped: INSTALL_REALITY=false"
	fi

	if should_install_hy2; then
		hy2_port_status="$(detect_udp_port_status "$HY2_PORT")"
		if [[ "$hy2_port_status" == managed\ by\ this\ project:* ]]; then
			log "HY2 existing managed install detected; refreshing config and client export"
			if install_hy2_stealth; then
				ALL_HY2_STATUS="installed / refreshed managed by this project"
				log "HY2 success"
			else
				ALL_HY2_STATUS="failed"
				all_failed=1
				warn "HY2 failed"
			fi
		elif [[ "$hy2_port_status" == local\ socket\ occupied* ]] && ! is_simulation; then
			ALL_HY2_STATUS="skipped: UDP ${HY2_PORT} conflict"
			all_failed=1
			warn "HY2 skipped: UDP ${HY2_PORT} appears occupied by an unknown process"
		else
			log "starting HY2"
			if install_hy2_stealth; then
				ALL_HY2_STATUS="installed"
				log "HY2 success"
			else
				ALL_HY2_STATUS="failed"
				all_failed=1
				warn "HY2 failed"
			fi
		fi
	else
		write_hy2_skipped_notice
		ALL_HY2_STATUS="skipped: INSTALL_HY2=false"
	fi

	if should_install_xhttp; then
		xhttp_port_status="$(detect_tcp_port_status "$XHTTP_HTTPS_PORT")"
		if [[ "$xhttp_port_status" == managed\ by\ this\ project:* ]]; then
			log "XHTTP existing managed install detected; refreshing config and client export"
			if install_xhttp_cdn; then
				ALL_XHTTP_STATUS="installed / refreshed managed by this project"
				log "XHTTP success"
			else
				ALL_XHTTP_STATUS="failed"
				all_failed=1
				warn "XHTTP failed"
			fi
		elif [[ "$xhttp_port_status" == "occupied" ]] && ! is_simulation; then
			ALL_XHTTP_STATUS="skipped: TCP ${XHTTP_HTTPS_PORT} conflict"
			all_failed=1
			warn "XHTTP skipped: TCP ${XHTTP_HTTPS_PORT} is occupied by an unknown process"
		else
			log "starting XHTTP"
			if install_xhttp_cdn; then
				ALL_XHTTP_STATUS="installed"
				log "XHTTP success"
			else
				ALL_XHTTP_STATUS="failed"
				all_failed=1
				warn "XHTTP failed"
			fi
		fi
	else
		write_xhttp_skipped_notice
		ALL_XHTTP_STATUS="skipped: INSTALL_XHTTP=false"
	fi

	log "starting Firewall"
	log "Firewall success: ports are handled during each scheme install"
	log "starting Summary"
	print_all_summary
	return "$all_failed"
}

print_all_summary() {
	cat <<EOF
Install summary
Reality: ${ALL_REALITY_STATUS}
Hysteria2: ${ALL_HY2_STATUS}
XHTTP+Caddy: ${ALL_XHTTP_STATUS}
BBR: ${ALL_BBR_STATUS}
Firewall: ${ALL_FIREWALL_STATUS}
credentials path: ${CREDENTIALS_FILE}
EOF
	log "final summary: Reality=${ALL_REALITY_STATUS}; Hysteria2=${ALL_HY2_STATUS}; XHTTP+Caddy=${ALL_XHTTP_STATUS}; BBR=${ALL_BBR_STATUS}; Firewall=${ALL_FIREWALL_STATUS}"
}

main() {
	local command="${1:-help}"
	if [[ $# -gt 0 ]]; then
		shift
	fi

	DRY_RUN=false
	TEST_MODE=false
	PURGE=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			DRY_RUN=true
			;;
		--test-mode)
			TEST_MODE=true
			;;
		--purge)
			PURGE=true
			;;
		-h | --help)
			usage
			return 0
			;;
		*)
			die "unknown option: $1"
			;;
		esac
		shift
	done

	init_runtime "${SCRIPT_DIR}"
	load_config_file

	case "$command" in
	all)
		run_all
		;;
	reality)
		detect_supported_os
		if should_install_reality; then
			require_public_host
			install_reality_vision
		else
			write_reality_skipped_notice
		fi
		;;
	hy2)
		detect_supported_os
		if should_install_hy2; then
			require_public_host
			install_hy2_stealth
		else
			write_hy2_skipped_notice
		fi
		;;
	xhttp)
		detect_supported_os
		if should_install_xhttp; then
			require_public_host
			install_xhttp_cdn
		else
			write_xhttp_skipped_notice
		fi
		;;
	bbr)
		detect_supported_os
		enable_bbr
		;;
	detect)
		show_detect_matrix
		;;
	status)
		show_status
		;;
	verify-exports)
		verify_exports
		;;
	uninstall)
		uninstall_all
		;;
	help | --help | -h)
		usage
		;;
	*)
		usage >&2
		die "unknown command: $command"
		;;
	esac
}

main "$@"
