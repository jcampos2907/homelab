#!/bin/bash
# Print a short-lived (15 min) OpenBao token for an AI agent identity.
#   export VAULT_TOKEN=$(openbao/agent-login.sh claude)   # or: codex
#   vault kv get ...                                       # VAULT_ADDR=https://vault.famcr.org
#   vault token revoke -self                               # when done
# Needs kubectl access to the cluster. Nothing is stored.
set -euo pipefail
AGENT="${1:?usage: agent-login.sh <claude|codex|...>}"
ADDR="${VAULT_ADDR:-https://vault.famcr.org}"

JWT=$(kubectl -n openbao create token "${AGENT}-ops" --duration 10m)
RESP=$(curl -sSk "$ADDR/v1/auth/kubernetes/login" -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg r "${AGENT}-ops" --arg j "$JWT" '{role:$r,jwt:$j}')")
TOKEN=$(jq -r '.auth.client_token // empty' <<<"$RESP")
[ -n "$TOKEN" ] || { jq -c '.errors' <<<"$RESP" >&2; exit 1; }
echo "$TOKEN"
