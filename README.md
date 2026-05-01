# VoidLLM Docker Compose

This stack runs VoidLLM behind Nginx with automatic Let's Encrypt certificate issuance.

## What it does

- VoidLLM runs in split-port mode:
  - `8080` for `/v1` proxy traffic and health endpoints
  - `8443` for the admin UI and `/api/*`
- Nginx starts on port `80` immediately to serve ACME HTTP-01 challenges.
- If `./volumes/letsencrypt/live/$DOMAIN` does not contain a certificate yet, Certbot requests one from Let's Encrypt.
- As soon as the cert lands in the mounted volume, Nginx switches itself to the HTTPS config and starts redirecting `80 -> 443`.
- Certbot keeps running and renews certificates in place.

## Before you start

- Point the DNS `A` or `AAAA` record for `DOMAIN` at the machine running Docker.
- Make sure inbound ports `80` and `443` are reachable from the public internet.
- Generate the required keys:

```bash
openssl rand -base64 32
openssl rand -base64 32
```

Use one value for `VOIDLLM_ADMIN_KEY` and one for `VOIDLLM_ENCRYPTION_KEY`.

## Usage

1. Copy `.env.example` to `.env` and fill in real values.
2. For the first real issuance, set `LETSENCRYPT_STAGING=0`.
3. Start the stack:

```bash
docker compose up -d
```

4. Watch the bootstrap logs:

```bash
docker compose logs -f certbot nginx voidllm
```

5. Once the certificate is issued, open `https://$DOMAIN`.

VoidLLM prints the bootstrap credentials once on first start. Save them from the `voidllm` logs.
