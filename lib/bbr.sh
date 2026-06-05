#!/usr/bin/env bash

enable_bbr() {
	local kernel_bbr_status

	if ! is_true "${ENABLE_BBR:-true}"; then
		log "BBR is disabled by configuration"
		return 0
	fi

	if is_dry_run; then
		log "dry-run: would detect and enable BBR when supported"
		return 0
	fi

	detect_platform
	if [[ "${IS_CONTAINER:-no}" == "yes" ]]; then
		warn "container environment detected (${VIRT_TYPE}); BBR sysctl changes may be unavailable; skipping automatic BBR apply"
		return 0
	fi

	if [[ "$(uname -s)" != "Linux" ]]; then
		warn "BBR requires Linux; skipping"
		return 0
	fi

	kernel_bbr_status="$(platform_kernel_bbr_status)"
	if [[ "$kernel_bbr_status" != "supported" ]]; then
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
