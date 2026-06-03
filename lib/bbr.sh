#!/usr/bin/env bash

enable_bbr() {
	if ! is_true "${ENABLE_BBR:-true}"; then
		log "BBR is disabled by configuration"
		return 0
	fi

	if is_dry_run; then
		log "dry-run: would detect and enable BBR when supported"
		return 0
	fi

	if [[ ! -w /etc/sysctl.conf ]]; then
		warn "cannot modify sysctl configuration; skipping BBR"
		return 0
	fi

	if ! sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr; then
		warn "kernel does not report BBR support; skipping"
		return 0
	fi

	grep -q '^net.core.default_qdisc=fq$' /etc/sysctl.conf || printf '%s\n' 'net.core.default_qdisc=fq' >>/etc/sysctl.conf
	grep -q '^net.ipv4.tcp_congestion_control=bbr$' /etc/sysctl.conf || printf '%s\n' 'net.ipv4.tcp_congestion_control=bbr' >>/etc/sysctl.conf
	sysctl -p >/dev/null || warn "sysctl reload failed; BBR settings may require manual review"
}

