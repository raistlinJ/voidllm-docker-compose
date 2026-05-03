#!/bin/sh
set -eu

KEY_PATH=/data/voidllm-encryption.key

load_or_generate_encryption_key() {
  if [ -n "${VOIDLLM_ENCRYPTION_KEY:-}" ]; then
    return
  fi

  if [ -s "$KEY_PATH" ]; then
    VOIDLLM_ENCRYPTION_KEY="$(cat "$KEY_PATH")"
    export VOIDLLM_ENCRYPTION_KEY
    return
  fi

  if command -v openssl >/dev/null 2>&1; then
    generated_key="$(openssl rand -base64 32 | tr -d '\n')"
  elif [ -r /proc/sys/kernel/random/uuid ]; then
    generated_key="$(cat /proc/sys/kernel/random/uuid)$(cat /proc/sys/kernel/random/uuid)"
  else
    echo "unable to generate VOIDLLM_ENCRYPTION_KEY automatically" >&2
    exit 1
  fi

  umask 077
  printf '%s\n' "$generated_key" > "$KEY_PATH"
  VOIDLLM_ENCRYPTION_KEY="$generated_key"
  export VOIDLLM_ENCRYPTION_KEY
  echo "generated persistent VOIDLLM_ENCRYPTION_KEY at $KEY_PATH"
}

load_or_generate_encryption_key

exec voidllm --config /etc/voidllm/voidllm.yaml
