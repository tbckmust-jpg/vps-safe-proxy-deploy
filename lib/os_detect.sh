#!/usr/bin/env bash

detect_supported_os() {
	if is_dry_run; then
		log "dry-run: skipping operating system changes"
		return 0
	fi

	if [[ ! -r /etc/os-release ]]; then
		die "cannot detect OS; supported systems are Debian 11/12 and Ubuntu 22.04/24.04"
	fi

	# shellcheck source=/dev/null
	. /etc/os-release

	case "${ID:-}:${VERSION_ID:-}" in
	debian:11 | debian:12 | ubuntu:22.04 | ubuntu:24.04)
		log "supported OS detected: ${PRETTY_NAME:-${ID} ${VERSION_ID}}"
		;;
	alpine:*)
		die "Alpine/OpenRC is not supported yet; exiting without installing systemd services"
		;;
	*)
		die "unsupported OS: ${PRETTY_NAME:-unknown}; supported systems are Debian 11/12 and Ubuntu 22.04/24.04"
		;;
	esac
}
