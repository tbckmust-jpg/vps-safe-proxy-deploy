#!/usr/bin/env bash

install_packages() {
	local package_manager
	local -a packages

	packages=("$@")
	[[ "${#packages[@]}" -gt 0 ]] || return 0

	if is_dry_run; then
		log "dry-run: would install packages: ${packages[*]}"
		return 0
	fi

	if is_test_mode; then
		log "test-mode: skipping package installation: ${packages[*]}"
		return 0
	fi

	require_root
	detect_platform
	package_manager="${PACKAGE_MANAGER:-unknown}"

	case "$package_manager" in
	apt)
		if ! apt-get update; then
			die "failed to update package index with apt"
		fi
		if ! apt-get install -y "${packages[@]}"; then
			die "failed to install required packages with apt: ${packages[*]}"
		fi
		;;
	dnf)
		if ! dnf install -y "${packages[@]}"; then
			die "failed to install required packages with dnf: ${packages[*]}"
		fi
		;;
	yum)
		if ! yum install -y "${packages[@]}"; then
			die "failed to install required packages with yum: ${packages[*]}"
		fi
		;;
	pacman)
		if ! pacman -Sy --noconfirm "${packages[@]}"; then
			die "failed to install required packages with pacman: ${packages[*]}"
		fi
		;;
	zypper)
		if ! zypper --non-interactive install "${packages[@]}"; then
			die "failed to install required packages with zypper: ${packages[*]}"
		fi
		;;
	*)
		die "unsupported package manager: ${package_manager}; cannot install required packages: ${packages[*]}"
		;;
	esac
}

install_system_dependencies() {
	install_packages curl unzip openssl ca-certificates
}
