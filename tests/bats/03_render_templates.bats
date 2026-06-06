#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"

  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 HY2_DOMAIN=hy2.example.com XHTTP_DOMAIN=cdn.example.com EMAIL=me@example.com \
    bash "$REPO_ROOT/install.sh" all --dry-run --test-mode
  [ "$status" -eq 0 ]
}

@test "Reality Vision template renders required fields" {
  file="$REPO_ROOT/tests/tmp/etc/xray/xray-reality-vision.json"

  grep -q '"protocol": "vless"' "$file"
  grep -q '"network": "raw"' "$file"
  grep -q '"security": "reality"' "$file"
  grep -q '"flow": "xtls-rprx-vision"' "$file"
  grep -q '"fingerprint": "chrome"' "$file"
  grep -q '"decryption": "none"' "$file"
}

@test "Hysteria2 template renders required fields" {
  file="$REPO_ROOT/tests/tmp/etc/hysteria/hysteria-server.yaml"

  grep -q '^listen:' "$file"
  grep -q 'type: password' "$file"
  grep -q '^tls:' "$file"
  grep -q '^masquerade:' "$file"
  grep -q 'salamander' "$file"
}

@test "Hysteria2 uses ACME mode when domain and email are provided" {
  file="$REPO_ROOT/tests/tmp/etc/hysteria/hysteria-server.yaml"

  grep -q 'mode: "acme"' "$file"
  grep -q 'hy2.example.com' "$file"
}

@test "Hysteria2 falls back to self-signed mode without HY2_DOMAIN" {
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"

  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 \
    bash "$REPO_ROOT/install.sh" hy2 --dry-run --test-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *"self-signed TLS mode"* ]]
  grep -q 'mode: "self-signed"' "$REPO_ROOT/tests/tmp/etc/hysteria/hysteria-server.yaml"
}

@test "Hysteria2 self-signed client export enables insecure verification" {
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"

  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 HY2_PASSWORD='a+b/c=' HY2_OBFS_PASSWORD='o+b/c=' \
    bash "$REPO_ROOT/install.sh" hy2 --dry-run --test-mode
  [ "$status" -eq 0 ]

  grep -q 'insecure: true' "$REPO_ROOT/tests/tmp/render/hysteria-client.yaml"
  grep -q 'self-signed mode, client must allow insecure certificate verification' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q 'a%2Bb%2Fc%3D' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q 'o%2Bb%2Fc%3D' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q 'insecure=1' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q 'sni=203.0.113.10' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q '"type":"hysteria2"' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q '"insecure":true' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q 'v2rayN_hint=' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
}

@test "Hysteria2 generated secrets are URL-safe for client URI imports" {
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"

  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 \
    bash "$REPO_ROOT/install.sh" hy2 --dry-run --test-mode
  [ "$status" -eq 0 ]

  file="$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  scheme="hysteria2"
  uri="$(grep '^uri=' "$file")"
  uri="${uri#uri=}"
  uri_auth="${uri#${scheme}://}"
  uri_auth="${uri_auth%@*}"
  uri_obfs="${uri#*obfs-password=}"
  uri_obfs="${uri_obfs%%&*}"
  uri_obfs="${uri_obfs%%#*}"

  [[ "$uri_auth" =~ ^[A-Za-z0-9_-]+$ ]]
  [[ "$uri_obfs" =~ ^[A-Za-z0-9_-]+$ ]]
  ! grep -Eq '^password=.*[+/=]' "$file"
}

@test "Hysteria2 ACME client export does not enable insecure verification" {
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"

  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 HY2_DOMAIN=hy2.example.com EMAIL=me@example.com \
    bash "$REPO_ROOT/install.sh" hy2 --dry-run --test-mode
  [ "$status" -eq 0 ]

  grep -q 'insecure: false' "$REPO_ROOT/tests/tmp/render/hysteria-client.yaml"
  ! grep -q 'insecure=1' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q 'sni=hy2.example.com' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q '"type":"hysteria2"' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q '"tls":{"enabled":true,"server_name":"hy2.example.com"}' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  ! grep -q '"insecure":true' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  ! grep -q 'self-signed mode' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
}

@test "XHTTP template renders internal listener and random path" {
  file="$REPO_ROOT/tests/tmp/etc/xray/xray-xhttp.json"

  grep -q '"network": "xhttp"' "$file"
  grep -q '"listen": "127.0.0.1"' "$file"
  grep -Eq '"path": "/assets/[a-f0-9]+"' "$file"
}

@test "XHTTP no-domain client export disables TLS" {
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"

  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 \
    bash "$REPO_ROOT/install.sh" xhttp --dry-run --test-mode
  [ "$status" -eq 0 ]

  grep -q 'security=none' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q 'host=203.0.113.10' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q '"tls":{"enabled":false}' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q '"Host":"203.0.113.10"' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  ! grep -q 'security=tls' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  ! grep -q 'server_name' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
}

@test "XHTTP domain client export enables TLS" {
  rm -rf "$REPO_ROOT/tests/tmp"
  mkdir -p "$REPO_ROOT/tests/tmp"

  run env -i PATH="$PATH" PUBLIC_HOST=203.0.113.10 XHTTP_DOMAIN=cdn.example.com \
    bash "$REPO_ROOT/install.sh" xhttp --dry-run --test-mode
  [ "$status" -eq 0 ]

  grep -q 'security=tls' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q 'sni=cdn.example.com' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q '"tls":{"enabled":true,"server_name":"cdn.example.com"}' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
  grep -q '"Host":"cdn.example.com"' "$REPO_ROOT/tests/tmp/root/vps-oneclick/credentials.txt"
}

@test "Caddyfile renders static site and random reverse proxy path" {
  file="$REPO_ROOT/tests/tmp/etc/caddy/Caddyfile"

  grep -q 'file_server' "$file"
  grep -Eq 'handle /assets/[a-f0-9]+\*' "$file"
  grep -q 'reverse_proxy 127.0.0.1:' "$file"
}
