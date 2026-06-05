server: "{{PUBLIC_HOST}}:{{HY2_CLIENT_PORT}}"
auth: "{{HY2_PASSWORD}}"

tls:
  sni: "{{HY2_DOMAIN}}"
  insecure: {{HY2_TLS_INSECURE}}

obfs:
  type: salamander
  salamander:
    password: "{{HY2_OBFS_PASSWORD}}"
