#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="${REPO_OWNER:-tbckmust-jpg}"
REPO_NAME="${REPO_NAME:-vps-safe-proxy-deploy}"
REPO_REF="${REPO_REF:-main}"

die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

need_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

use_temp_repo_only() {
	local arg

	case "${1:-}" in
	detect | help | -h | --help)
		return 0
		;;
	esac

	for arg in "$@"; do
		case "$arg" in
		--dry-run | --test-mode)
			return 0
			;;
		esac
	done

	return 1
}

persist_repo() {
	local source_dir="$1"
	local persist_dir="${INSTALL_DIR:-/opt/vps-safe-proxy-deploy}"

	case "$persist_dir" in
	/opt/vps-safe-proxy-deploy | /opt/vps-safe-proxy-deploy/*) ;;
	*) die "INSTALL_DIR must stay under /opt/vps-safe-proxy-deploy for real installation" ;;
	esac

	mkdir -p "$persist_dir" || die "failed to create persistent installer directory: ${persist_dir}"
	cp -R "${source_dir}/." "$persist_dir/" || die "failed to persist installer to ${persist_dir}"

	if [[ ! -x "${persist_dir}/install.sh" ]]; then
		chmod +x "${persist_dir}/install.sh" || die "failed to mark ${persist_dir}/install.sh executable"
	fi

	printf '%s\n' "$persist_dir"
}

main() {
	need_cmd bash
	need_cmd curl
	need_cmd tar

	local tmp_dir archive repo_dir persist_dir
	tmp_dir="$(mktemp -d)"
	archive="${tmp_dir}/source.tar.gz"
	trap 'rm -rf "$tmp_dir"' EXIT

	curl -fsSL "https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/${REPO_REF}.tar.gz" -o "$archive"
	tar -xzf "$archive" -C "$tmp_dir"
	repo_dir="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
	[[ -n "$repo_dir" ]] || die "archive did not contain a project directory"

	if [[ ! -x "${repo_dir}/install.sh" ]]; then
		chmod +x "${repo_dir}/install.sh"
	fi

	if ! use_temp_repo_only "$@"; then
		persist_dir="$(persist_repo "$repo_dir")"
		exec bash "${persist_dir}/install.sh" "$@"
	fi

	exec bash "${repo_dir}/install.sh" "$@"
}

main "$@"
