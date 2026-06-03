#!/usr/bin/env bash

detect_supported_os() {
	local os_release_file

	if is_simulation; then
		log "simulation: skipping operating system changes"
		return 0
	fi

	os_release_file="${OS_RELEASE_FILE:-/etc/os-release}"

	if [[ ! -r "$os_release_file" ]]; then
		die "cannot detect OS; supported systems are Debian 11/12 and Ubuntu 22.04/24.04"
	fi

	# shellcheck source=/dev/null
	. "$os_release_file"

	case "${ID:-}:${VERSION_ID:-}" in
	debian:11 | debian:12 | ubuntu:22.04 | ubuntu:24.04)
		log "supported OS detected: ${PRETTY_NAME:-${ID} ${VERSION_ID}}"
		;;
	alpine:*)
		die "Alpine/OpenRC is not supported for real installation. Use --dry-run or use Debian/Ubuntu with systemd."
		;;
	*)
		die "unsupported OS: ${PRETTY_NAME:-unknown}; supported systems are Debian 11/12 and Ubuntu 22.04/24.04"
		;;
	esac

	if ! command -v systemctl >/dev/null 2>&1; then
		die "current system does not use systemd; real installation is not supported. Use --dry-run or --test-mode only."
	fi
}
