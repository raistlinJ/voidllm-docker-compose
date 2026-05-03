#!/bin/sh
set -eu

require_env() {
  var_name="$1"
  eval "var_value=\${$var_name:-}"
  if [ -z "$var_value" ]; then
    echo "missing required environment variable: $var_name" >&2
    exit 1
  fi
}

cert_ready() {
  [ -f "/etc/letsencrypt/fullchain.pem" ] && [ -f "/etc/letsencrypt/privkey.pem" ]
}

sync_active_cert_files() {
  if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] || [ ! -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
    return 1
  fi

  cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "/etc/letsencrypt/fullchain.pem"
  cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "/etc/letsencrypt/privkey.pem"
}

wait_for_nginx() {
  python3 - <<'PY'
import sys
import time
import urllib.request

url = 'http://nginx/nginx-health'
deadline = time.time() + 180

while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=5) as response:
            if response.status == 200:
                sys.exit(0)
    except Exception:
        time.sleep(2)

sys.exit(1)
PY
}

request_certificate() {
  if [ "${LETSENCRYPT_STAGING:-0}" = "1" ]; then
    certbot certonly \
      --staging \
      --webroot \
      --webroot-path "$CERTBOT_WEBROOT" \
      --email "$LETSENCRYPT_EMAIL" \
      --agree-tos \
      --non-interactive \
      --keep-until-expiring \
      --cert-name "$DOMAIN" \
      -d "$DOMAIN"
    return
  fi

  certbot certonly \
    --webroot \
    --webroot-path "$CERTBOT_WEBROOT" \
    --email "$LETSENCRYPT_EMAIL" \
    --agree-tos \
    --non-interactive \
    --keep-until-expiring \
    --cert-name "$DOMAIN" \
    -d "$DOMAIN"
}

renew_certificates() {
  certbot renew \
    --webroot \
    --webroot-path "$CERTBOT_WEBROOT" \
    --quiet
}

require_env DOMAIN
require_env LETSENCRYPT_EMAIL
require_env CERTBOT_WEBROOT

mkdir -p "$CERTBOT_WEBROOT"

if ! wait_for_nginx; then
  echo "nginx did not become reachable on port 80 in time" >&2
  exit 1
fi

while :; do
  if cert_ready; then
    if renew_certificates; then
      sync_active_cert_files || true
      sleep "${CERTBOT_RENEW_INTERVAL:-43200}"
      continue
    fi

    echo "certificate renewal failed; retrying sooner" >&2
    sleep "${CERTBOT_RETRY_INTERVAL:-300}"
    continue
  fi

  if request_certificate; then
    if ! sync_active_cert_files; then
      echo "certificate issued but active cert files were not created" >&2
      sleep "${CERTBOT_RETRY_INTERVAL:-300}"
      continue
    fi

    sleep "${CERTBOT_RENEW_INTERVAL:-43200}"
    continue
  fi

  echo "initial certificate request failed; retrying" >&2
  sleep "${CERTBOT_RETRY_INTERVAL:-300}"
done