#!/usr/bin/env bash
# shellcheck disable=SC2034

platform_read_os_release() {
	local os_release_file="${OS_RELEASE_FILE:-/etc/os-release}"
	local ID=""
	local NAME=""
	local PRETTY_NAME=""
	local VERSION_ID=""

	OS_ID="unknown"
	OS_VERSION_ID="unknown"
	OS_NAME="unknown"
	OS_PRETTY_NAME="unknown"

	if [[ -r "$os_release_file" ]]; then
		# shellcheck source=/dev/null
		. "$os_release_file"
		OS_ID="${ID:-unknown}"
		OS_VERSION_ID="${VERSION_ID:-unknown}"
		OS_NAME="${NAME:-unknown}"
		OS_PRETTY_NAME="${PRETTY_NAME:-${NAME:-unknown} ${VERSION_ID:-unknown}}"
	fi
}

platform_detect_family() {
	case "${OS_ID:-unknown}" in
	debian | ubuntu)
		OS_FAMILY="debian"
		;;
	fedora | rocky | almalinux | rhel | centos)
		OS_FAMILY="redhat"
		;;
	arch | archlinux)
		OS_FAMILY="arch"
		;;
	opensuse* | sles)
		OS_FAMILY="suse"
		;;
	alpine)
		OS_FAMILY="alpine"
		;;
	*)
		OS_FAMILY="unknown"
		;;
	esac
}

platform_detect_init_system() {
	if [[ -n "${DETECT_INIT_SYSTEM:-}" ]]; then
		INIT_SYSTEM="$DETECT_INIT_SYSTEM"
	elif is_test_mode && command -v systemctl >/dev/null 2>&1; then
		INIT_SYSTEM="systemd"
	elif [[ -d /run/systemd/system ]]; then
		INIT_SYSTEM="systemd"
	elif [[ -d /run/openrc ]] || command -v rc-service >/dev/null 2>&1; then
		INIT_SYSTEM="openrc"
	elif [[ -r /proc/1/comm ]]; then
		case "$(cat /proc/1/comm 2>/dev/null || true)" in
		systemd)
			INIT_SYSTEM="systemd"
			;;
		openrc*)
			INIT_SYSTEM="openrc"
			;;
		*)
			INIT_SYSTEM="unknown"
			;;
		esac
	else
		INIT_SYSTEM="unknown"
	fi
}

platform_detect_arch() {
	ARCH="${DETECT_ARCH:-$(uname -m 2>/dev/null || printf 'unknown')}"
}

platform_arch_supported() {
	case "${ARCH:-unknown}" in
	x86_64 | amd64) return 0 ;;
	*) return 1 ;;
	esac
}

platform_detect_root() {
	if [[ -n "${DETECT_IS_ROOT:-}" ]]; then
		if is_true "$DETECT_IS_ROOT"; then
			IS_ROOT="yes"
		else
			IS_ROOT="no"
		fi
	elif [[ "$(id -u 2>/dev/null || printf '1')" == "0" ]]; then
		IS_ROOT="yes"
	else
		IS_ROOT="no"
	fi
}

platform_detect_virtualization() {
	local cgroup_file docker_env_file environ_file proc_vz_dir product_name status_file systemd_container_file virt
	local -a environ_files

	if [[ -n "${DETECT_VIRT:-}" ]]; then
		VIRT_TYPE="$DETECT_VIRT"
		return 0
	fi

	if ! is_true "${DETECT_SKIP_SYSTEMD_DETECT_VIRT:-false}" && command -v systemd-detect-virt >/dev/null 2>&1; then
		virt="$(systemd-detect-virt --container 2>/dev/null || true)"
		case "$virt" in
		lxc | lxc-libvirt | systemd-nspawn)
			VIRT_TYPE="LXC"
			return 0
			;;
		docker | podman | containerd)
			VIRT_TYPE="Docker"
			return 0
			;;
		esac

		virt="$(systemd-detect-virt --vm 2>/dev/null || true)"
		case "$virt" in
		kvm | qemu | microsoft | oracle | xen | vmware)
			VIRT_TYPE="KVM"
			return 0
			;;
		esac
	fi

	systemd_container_file="${DETECT_SYSTEMD_CONTAINER_FILE:-/run/systemd/container}"
	if [[ -r "$systemd_container_file" ]]; then
		case "$(cat "$systemd_container_file" 2>/dev/null || true)" in
		lxc | lxc-libvirt | systemd-nspawn)
			VIRT_TYPE="LXC"
			return 0
			;;
		docker | podman | containerd)
			VIRT_TYPE="Docker"
			return 0
			;;
		esac
	fi

	docker_env_file="${DETECT_DOCKERENV_FILE:-/.dockerenv}"
	if [[ -f "$docker_env_file" ]]; then
		VIRT_TYPE="Docker"
		return 0
	fi

	for cgroup_file in "${DETECT_PROC_1_CGROUP_FILE:-/proc/1/cgroup}" "${DETECT_PROC_SELF_CGROUP_FILE:-/proc/self/cgroup}"; do
		[[ -r "$cgroup_file" ]] || continue
		if grep -Eiq '(^|/)(lxc|lxc\.payload|libpod-lxc)(/|$)' "$cgroup_file"; then
			VIRT_TYPE="LXC"
			return 0
		fi
		if grep -Eiq '(docker|containerd|kubepods|libpod)' "$cgroup_file"; then
			VIRT_TYPE="Docker"
			return 0
		fi
	done

	environ_files=("${DETECT_PROC_1_ENVIRON_FILE:-/proc/1/environ}" "${DETECT_PROC_SELF_ENVIRON_FILE:-/proc/self/environ}")
	for environ_file in "${environ_files[@]}"; do
		[[ -r "$environ_file" ]] || continue
		if tr '\0' '\n' <"$environ_file" 2>/dev/null | grep -Eiq '^container=(lxc|lxc-libvirt|systemd-nspawn)$'; then
			VIRT_TYPE="LXC"
			return 0
		fi
		if tr '\0' '\n' <"$environ_file" 2>/dev/null | grep -Eiq '^container=(docker|podman|containerd)$'; then
			VIRT_TYPE="Docker"
			return 0
		fi
	done

	status_file="${DETECT_PROC_SELF_STATUS_FILE:-/proc/self/status}"
	if [[ -r "$status_file" ]] && grep -Eq '^NSpid:[[:space:]]+[0-9]+[[:space:]]+[0-9]+' "$status_file"; then
		VIRT_TYPE="LXC"
		return 0
	fi

	proc_vz_dir="${DETECT_PROC_VZ_DIR:-/proc/vz}"
	if [[ -d "$proc_vz_dir" ]]; then
		VIRT_TYPE="LXC"
		return 0
	fi

	if [[ -r "${DETECT_DMI_PRODUCT_NAME_FILE:-/sys/class/dmi/id/product_name}" ]]; then
		product_name="$(cat "${DETECT_DMI_PRODUCT_NAME_FILE:-/sys/class/dmi/id/product_name}" 2>/dev/null || true)"
		if [[ "$product_name" == *KVM* || "$product_name" == *QEMU* ]]; then
			VIRT_TYPE="KVM"
			return 0
		elif [[ "$product_name" == *Virtual* ]]; then
			VIRT_TYPE="VPS"
			return 0
		fi
	fi

	VIRT_TYPE="unknown"
}

platform_is_container_virt() {
	case "$1" in
	LXC | Docker | OpenVZ | lxc | docker | openvz) return 0 ;;
	*) return 1 ;;
	esac
}

platform_detect_container() {
	if platform_is_container_virt "${VIRT_TYPE:-unknown}"; then
		IS_CONTAINER="yes"
	else
		IS_CONTAINER="no"
	fi
}

platform_detect_package_manager() {
	if [[ -n "${DETECT_PACKAGE_MANAGER:-}" ]]; then
		PACKAGE_MANAGER="$DETECT_PACKAGE_MANAGER"
	elif command -v apt-get >/dev/null 2>&1; then
		PACKAGE_MANAGER="apt"
	elif command -v dnf >/dev/null 2>&1; then
		PACKAGE_MANAGER="dnf"
	elif command -v yum >/dev/null 2>&1; then
		PACKAGE_MANAGER="yum"
	elif command -v pacman >/dev/null 2>&1; then
		PACKAGE_MANAGER="pacman"
	elif command -v zypper >/dev/null 2>&1; then
		PACKAGE_MANAGER="zypper"
	else
		PACKAGE_MANAGER="unknown"
	fi
}

platform_package_manager_supported() {
	case "${PACKAGE_MANAGER:-unknown}" in
	apt | dnf | yum | pacman | zypper) return 0 ;;
	*) return 1 ;;
	esac
}

platform_detect_service_manager() {
	case "${INIT_SYSTEM:-unknown}" in
	systemd)
		SERVICE_MANAGER="systemd"
		;;
	openrc | OpenRC)
		SERVICE_MANAGER="openrc"
		;;
	*)
		SERVICE_MANAGER="unknown"
		;;
	esac
}

platform_kernel_bbr_status() {
	local sysctl_output

	if [[ "${MOCK_BBR_UNSUPPORTED:-0}" == "1" ]]; then
		printf 'unsupported\n'
		return 0
	fi

	if [[ -n "${DETECT_BBR_STATUS:-}" ]]; then
		printf '%s\n' "$DETECT_BBR_STATUS"
	elif [[ -n "${DETECT_BBR_AVAILABLE:-}" ]]; then
		if is_true "$DETECT_BBR_AVAILABLE"; then
			printf 'supported\n'
		else
			printf 'unsupported\n'
		fi
	elif [[ "$(uname -s 2>/dev/null || true)" != "Linux" ]]; then
		printf 'unknown\n'
	elif [[ -r /proc/sys/net/ipv4/tcp_available_congestion_control ]]; then
		if grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control; then
			printf 'supported\n'
		else
			printf 'unsupported\n'
		fi
	elif command -v sysctl >/dev/null 2>&1; then
		sysctl_output="$(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null || true)"
		if printf '%s\n' "$sysctl_output" | grep -qw bbr; then
			printf 'supported\n'
		else
			printf 'unsupported\n'
		fi
	else
		printf 'unknown\n'
	fi
}

detect_platform() {
	platform_read_os_release
	platform_detect_family
	platform_detect_init_system
	platform_detect_arch
	platform_detect_root
	platform_detect_virtualization
	platform_detect_container
	platform_detect_package_manager
	platform_detect_service_manager

	SUPPORT_LEVEL="unsupported"
	SUPPORT_REASON="unsupported platform"

	if [[ "${OS_FAMILY:-unknown}" == "alpine" ]]; then
		SUPPORT_LEVEL="dry-run only"
		SUPPORT_REASON="Alpine/OpenRC is not supported for real installation"
	elif [[ "${SERVICE_MANAGER:-unknown}" == "openrc" ]]; then
		SUPPORT_LEVEL="dry-run only"
		SUPPORT_REASON="Alpine/OpenRC is not supported for real installation"
	elif [[ "${SERVICE_MANAGER:-unknown}" != "systemd" ]]; then
		SUPPORT_LEVEL="unsupported"
		SUPPORT_REASON="systemd is required for real installation"
	elif [[ "${IS_ROOT:-no}" != "yes" ]]; then
		SUPPORT_LEVEL="dry-run only"
		SUPPORT_REASON="real installation requires root"
	elif ! platform_arch_supported; then
		SUPPORT_LEVEL="unsupported"
		SUPPORT_REASON="unsupported architecture: ${ARCH}"
	elif ! platform_package_manager_supported; then
		SUPPORT_LEVEL="unsupported"
		SUPPORT_REASON="unsupported or missing package manager"
	else
		SUPPORT_LEVEL="full install candidate"
		SUPPORT_REASON="systemd, root, supported architecture, and supported package manager detected"
	fi

	export OS_ID OS_VERSION_ID OS_NAME OS_PRETTY_NAME OS_FAMILY
	export INIT_SYSTEM PACKAGE_MANAGER SERVICE_MANAGER ARCH VIRT_TYPE IS_CONTAINER IS_ROOT SUPPORT_LEVEL SUPPORT_REASON
}

require_full_install_candidate() {
	detect_platform
	if [[ "${SUPPORT_LEVEL:-unsupported}" != "full install candidate" ]]; then
		die "real installation is not supported on this platform: ${SUPPORT_LEVEL}; ${SUPPORT_REASON}. Use ./install.sh detect or --dry-run."
	fi
}
