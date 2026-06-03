{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "xhttp-internal-in",
      "listen": "{{XHTTP_INTERNAL_HOST}}",
      "port": {{XHTTP_INTERNAL_PORT}},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "{{XHTTP_UUID}}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "path": "{{XHTTP_PATH}}"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}

