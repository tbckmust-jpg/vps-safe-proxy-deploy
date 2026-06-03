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

main() {
	need_cmd bash
	need_cmd curl
	need_cmd tar

	local tmp_dir archive repo_dir
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

	exec bash "${repo_dir}/install.sh" "$@"
}

main "$@"
