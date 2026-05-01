#!/bin/sh
set -eu

template_dir=/opt/nginx/templates
config_path=/etc/nginx/conf.d/default.conf
fingerprint_path=/tmp/current-cert-fingerprint

require_env() {
  var_name="$1"
  eval "var_value=\${$var_name:-}"
  if [ -z "$var_value" ]; then
    echo "missing required environment variable: $var_name" >&2
    exit 1
  fi
}

cert_ready() {
  [ -f "$LETSENCRYPT_LIVE_DIR/fullchain.pem" ] && [ -f "$LETSENCRYPT_LIVE_DIR/privkey.pem" ]
}

render_config() {
  template_name=bootstrap.conf.template
  if cert_ready; then
    template_name=tls.conf.template
  fi

  envsubst '${DOMAIN} ${CERTBOT_WEBROOT}' \
    < "$template_dir/$template_name" \
    > "$config_path"
}

cert_fingerprint() {
  if cert_ready; then
    cksum "$LETSENCRYPT_LIVE_DIR/fullchain.pem" "$LETSENCRYPT_LIVE_DIR/privkey.pem" | cksum | awk '{print $1}'
  else
    echo missing
  fi
}

watch_certificates() {
  last_fingerprint="$(cert_fingerprint)"
  printf '%s\n' "$last_fingerprint" > "$fingerprint_path"

  while :; do
    sleep 15
    next_fingerprint="$(cert_fingerprint)"
    current_fingerprint="$(cat "$fingerprint_path" 2>/dev/null || true)"

    if [ "$next_fingerprint" != "$current_fingerprint" ]; then
      render_config
      nginx -s reload
      printf '%s\n' "$next_fingerprint" > "$fingerprint_path"
    fi
  done
}

require_env DOMAIN
require_env CERTBOT_WEBROOT
require_env LETSENCRYPT_LIVE_DIR

mkdir -p /var/cache/nginx "$CERTBOT_WEBROOT"
render_config
watch_certificates &

exec nginx -g 'daemon off;'
