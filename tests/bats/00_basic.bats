#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "required top-level files exist" {
  [ -f "$REPO_ROOT/install.sh" ]
  [ -f "$REPO_ROOT/bootstrap.sh" ]
  [ -f "$REPO_ROOT/config.env.example" ]
  [ -f "$REPO_ROOT/README.md" ]
  [ -f "$REPO_ROOT/AGENTS.md" ]
  [ -f "$REPO_ROOT/.gitignore" ]
}

@test "entrypoint scripts are executable" {
  [ -x "$REPO_ROOT/install.sh" ]
  [ -x "$REPO_ROOT/bootstrap.sh" ]
}

@test "required directories exist" {
  [ -d "$REPO_ROOT/lib" ]
  [ -d "$REPO_ROOT/templates" ]
  [ -d "$REPO_ROOT/tests/bats" ]
  [ -d "$REPO_ROOT/tests/fixtures" ]
  [ -d "$REPO_ROOT/tests/mocks" ]
  [ -d "$REPO_ROOT/.github/workflows" ]
}

@test "bash syntax is valid" {
  run bash -n "$REPO_ROOT/bootstrap.sh"
  [ "$status" -eq 0 ]

  run bash -n "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]

  for file in "$REPO_ROOT"/lib/*.sh; do
    run bash -n "$file"
    [ "$status" -eq 0 ]
  done
}

@test "bootstrap persists real installs and keeps detect or dry-run temporary" {
  grep -q '/opt/vps-safe-proxy-deploy' "$REPO_ROOT/bootstrap.sh"
  grep -q 'use_temp_repo_only' "$REPO_ROOT/bootstrap.sh"
  grep -q 'exec bash "${persist_dir}/install.sh"' "$REPO_ROOT/bootstrap.sh"
  grep -q 'exec bash "${repo_dir}/install.sh"' "$REPO_ROOT/bootstrap.sh"
}
