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

	if [[ "$(uname -s)" != "Linux" ]]; then
		warn "BBR requires Linux; skipping"
		return 0
	fi

	if ! sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr; then
		warn "kernel does not report BBR support; skipping"
		return 0
	fi

	require_root
	mkdir -p "$(dirname "$SYSCTL_BBR_FILE")"
	cat >"$SYSCTL_BBR_FILE" <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

	if ! sysctl --system >/dev/null; then
		warn "sysctl --system failed; BBR settings may require manual review"
	fi
}
