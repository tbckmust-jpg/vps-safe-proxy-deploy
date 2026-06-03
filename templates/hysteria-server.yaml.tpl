listen: :{{HY2_PORT}}

auth:
  type: password
  password: "{{HY2_PASSWORD}}"

tls:
  mode: "{{HY2_TLS_MODE}}"
  domains:
    - "{{HY2_DOMAIN}}"
  cert: "{{HY2_CERT_FILE}}"
  key: "{{HY2_KEY_FILE}}"

masquerade:
  type: "{{MASQUERADE_MODE}}"
  file:
    dir: "{{HY2_MASQUERADE_DIR}}"
  proxy:
    url: "{{MASQUERADE_PROXY_URL}}"

obfs:
  type: salamander
  salamander:
    password: "{{HY2_OBFS_PASSWORD}}"

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520

