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

