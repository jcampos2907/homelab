#!/bin/bash
# Configure OpenBao login through Keycloak (OIDC), following
# https://developer.hashicorp.com/vault/tutorials/auth-methods/oidc-auth
#
# - Keycloak: client `vault` in realm `master` (confidential). Its `groups` mapper puts
#   the user's realm roles in the `groups` claim. Realm role `vault-admins` => OpenBao admin.
# - The client secret is read from the Keycloak DB. The admin token comes from
#   $VAULT_TOKEN or a hidden prompt. Neither is printed. Safe to re-run.
set -euo pipefail

ADDR="${VAULT_ADDR_OVERRIDE:-https://vault.famcr.org}"
TOKEN="${VAULT_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  read -rsp "OpenBao root/admin token (hidden): " TOKEN </dev/tty; echo
fi
[ -n "$TOKEN" ] || { echo "No token given"; exit 1; }

api() { # api METHOD PATH [JSON]
  curl -sSk -X "$1" -H "X-Vault-Token: $TOKEN" ${3:+-H 'Content-Type: application/json' -d "$3"} "$ADDR/v1/$2"
}

echo "==> Checking token"
api GET auth/token/lookup-self | jq -e '.data.policies' >/dev/null || { echo "Token rejected by $ADDR"; exit 1; }

echo "==> Reading Keycloak client secret for 'vault'"
PG=$(kubectl -n homelab-pg get pods -l cnpg.io/instanceRole=primary -o name | head -1)
CLIENT_SECRET=$(kubectl -n homelab-pg exec "$PG" -c postgres -- psql -d keycloak -At -c \
  "select c.secret from client c join realm r on r.id=c.realm_id where r.name='master' and c.client_id='vault'")
[ -n "$CLIENT_SECRET" ] || { echo "Client secret not found"; exit 1; }

echo "==> Policy 'admin'"
api PUT sys/policies/acl/admin "$(jq -nc --arg p 'path "*" { capabilities = ["create","read","update","patch","delete","list","sudo"] }' '{policy:$p}')"

echo "==> Enable oidc auth (if missing)"
if ! api GET sys/auth | jq -e '.data["oidc/"]' >/dev/null; then
  api POST sys/auth/oidc '{"type":"oidc","description":"Keycloak (master realm)"}'
fi
api POST sys/auth/oidc/tune '{"listing_visibility":"unauth"}'

echo "==> oidc config"
api POST auth/oidc/config "$(jq -nc --arg s "$CLIENT_SECRET" '{
  oidc_discovery_url: "https://keycloak.famcr.org/realms/master",
  oidc_client_id: "vault", oidc_client_secret: $s, default_role: "default"}')"
unset CLIENT_SECRET

echo "==> oidc role 'default'"
api POST auth/oidc/role/default '{
  "role_type": "oidc",
  "bound_audiences": ["vault"],
  "allowed_redirect_uris": ["https://vault.famcr.org/ui/vault/auth/oidc/oidc/callback", "http://localhost:8250/oidc/callback"],
  "user_claim": "preferred_username",
  "groups_claim": "groups",
  "oidc_scopes": ["openid", "profile", "email"],
  "token_policies": ["default"],
  "token_ttl": "8h",
  "token_max_ttl": "24h"
}'

echo "==> External group 'admins' <- Keycloak role 'vault-admins'"
api POST identity/group/name/admins '{"type":"external","policies":["admin"],"metadata":{"source":"keycloak vault-admins"}}' >/dev/null
GROUP_ID=$(api GET identity/group/name/admins | jq -r .data.id)
ACCESSOR=$(api GET sys/auth | jq -r '.data["oidc/"].accessor')
if ! api GET identity/group/name/admins | jq -e '.data.alias.name == "vault-admins"' >/dev/null; then
  api POST identity/group-alias "$(jq -nc --arg g "$GROUP_ID" --arg a "$ACCESSOR" '{name:"vault-admins",mount_accessor:$a,canonical_id:$g}')" >/dev/null
fi

echo "==> Done. Check:"
api GET auth/oidc/role/default | jq -c '.data | {user_claim, groups_claim, token_policies, allowed_redirect_uris}'
api GET identity/group/name/admins | jq -c '.data | {name, type, policies, alias: .alias.name}'
echo "Log in: UI -> Method OIDC -> Sign in;  CLI: bao login -method=oidc"
