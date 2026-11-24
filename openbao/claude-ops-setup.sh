#!/bin/bash
# Give Claude Code sessions their own short-lived OpenBao login:
#   Kubernetes SA openbao/claude-ops  ->  auth/kubernetes/role/claude-ops  ->  policy claude-ops
# Tokens last 15 min (30 min max) and nothing is stored. Run once with an admin token
# (after `vault login -method=oidc`, or it prompts). Safe to re-run.
#
# Scope: admin minus the dangerous endpoints (seal, root generation, rekey, raw storage,
# raft peers/snapshots, audit devices) and minus the obvious ways to raise its own rights
# (its own policy/role, the admin policy, identity groups/entities, token roles, oidc auth).
# Note: kubectl cluster-admin can already reach far into the cluster; this doesn't widen that.
#
# Claude logs in with:
#   T=$(curl -sk https://vault.famcr.org/v1/auth/kubernetes/login -d "{\"role\":\"claude-ops\",\"jwt\":\"$(kubectl -n openbao create token claude-ops --duration 10m)\"}" | jq -r .auth.client_token)
# Revoke: `vault delete auth/kubernetes/role/claude-ops` or delete the ServiceAccount.
set -euo pipefail

ADDR="${VAULT_ADDR:-https://vault.famcr.org}"
TOKEN="${VAULT_TOKEN:-$(cat ~/.vault-token 2>/dev/null || true)}"
if [ -z "$TOKEN" ]; then
  read -rsp "OpenBao admin token (hidden): " TOKEN </dev/tty; echo
fi
[ -n "$TOKEN" ] || { echo "No token given"; exit 1; }

api() { # api METHOD PATH [JSON]
  curl -sSk -X "$1" -H "X-Vault-Token: $TOKEN" ${3:+-H 'Content-Type: application/json' -d "$3"} "$ADDR/v1/$2"
}

echo "==> Checking token against $ADDR"
api GET auth/token/lookup-self | jq -e '.data.policies' >/dev/null || { echo "Token rejected (log in first: vault login -method=oidc)"; exit 1; }

echo "==> ServiceAccount openbao/claude-ops"
kubectl apply -f "$(dirname "$0")/claude-ops-sa.yaml"

echo "==> Policy 'claude-ops'"
read -r -d '' POLICY <<'HCL' || true
# Everything...
path "*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list", "sudo"]
}

# ...except the dangerous endpoints
path "sys/seal"                         { capabilities = ["deny"] }
path "sys/generate-root*"               { capabilities = ["deny"] }
path "sys/generate-recovery-token*"     { capabilities = ["deny"] }
path "sys/rekey*"                       { capabilities = ["deny"] }
path "sys/rekey-recovery-key*"          { capabilities = ["deny"] }
path "sys/rotate*"                      { capabilities = ["deny"] }
path "sys/raw*"                         { capabilities = ["deny"] }
path "sys/storage/*"                    { capabilities = ["deny"] }
path "sys/audit"                        { capabilities = ["deny"] }
path "sys/audit/*"                      { capabilities = ["deny"] }
path "sys/config/auditing/*"            { capabilities = ["deny"] }

# ...and the ways to grant itself more
path "sys/policy/claude-ops"            { capabilities = ["deny"] }
path "sys/policies/acl/claude-ops"      { capabilities = ["deny"] }
path "sys/policy/admin"                 { capabilities = ["deny"] }
path "sys/policies/acl/admin"           { capabilities = ["deny"] }
path "sys/policy/root"                  { capabilities = ["deny"] }
path "sys/policies/acl/root"            { capabilities = ["deny"] }
path "auth/kubernetes/role/claude-ops"  { capabilities = ["deny"] }
path "auth/kubernetes/config"           { capabilities = ["deny"] }
path "auth/oidc/*"                      { capabilities = ["deny"] }
path "sys/auth/oidc*"                   { capabilities = ["deny"] }
path "sys/auth/kubernetes*"             { capabilities = ["deny"] }
path "identity/group*"                  { capabilities = ["deny"] }
path "identity/entity*"                 { capabilities = ["deny"] }
path "auth/token/roles/*"               { capabilities = ["deny"] }
path "auth/token/create-orphan"         { capabilities = ["deny"] }
HCL
api PUT sys/policies/acl/claude-ops "$(jq -nc --arg p "$POLICY" '{policy:$p}')"

echo "==> Kubernetes auth role 'claude-ops'"
api GET sys/auth | jq -e '.data["kubernetes/"]' >/dev/null || { echo "kubernetes auth not enabled"; exit 1; }
api POST auth/kubernetes/role/claude-ops '{
  "bound_service_account_names": ["claude-ops"],
  "bound_service_account_namespaces": ["openbao"],
  "audience": "https://kubernetes.default.svc.cluster.local",
  "token_policies": ["claude-ops"],
  "token_ttl": "15m",
  "token_max_ttl": "30m",
  "token_no_default_policy": false
}'

echo "==> Test login as claude-ops"
JWT=$(kubectl -n openbao create token claude-ops --duration 10m)
curl -sSk "$ADDR/v1/auth/kubernetes/login" -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg j "$JWT" '{role:"claude-ops",jwt:$j}')" \
  | jq -c '{errors, policies: .auth.policies, ttl: .auth.lease_duration, user: .auth.metadata.service_account_name}'
echo "Done."
