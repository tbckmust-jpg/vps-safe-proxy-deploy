#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"
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

usage() {
	cat <<'USAGE'
Usage: ./install.sh <command> [--dry-run] [--test-mode] [--purge]

Commands:
	all        Run bbr, reality, hy2, and xhttp
	reality    Render/install VLESS REALITY Vision
	hy2        Render/install Hysteria2 stealth mode
	xhttp      Render/install VLESS XHTTP with Caddy
	bbr        Detect and enable BBR when supported
	status     Show service status
	uninstall  Remove installed services; keeps credentials unless --purge
USAGE
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
		detect_supported_os
		enable_bbr
		require_public_host
		if should_install_reality; then
			install_reality_vision
		else
			write_reality_skipped_notice
		fi
		if should_install_hy2; then
			install_hy2_stealth
		else
			write_hy2_skipped_notice
		fi
		if should_install_xhttp; then
			install_xhttp_cdn
		else
			write_xhttp_skipped_notice
		fi
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
	status)
		show_status
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
