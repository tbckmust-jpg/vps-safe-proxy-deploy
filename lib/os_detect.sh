#!/usr/bin/env bash

detect_supported_os() {
	if is_simulation; then
		log "simulation: skipping operating system changes"
		return 0
	fi

	require_full_install_candidate
	log "platform candidate detected: ${OS_PRETTY_NAME}; package manager=${PACKAGE_MANAGER}; service manager=${SERVICE_MANAGER}"
}
