#!/bin/bash
# Give AI coding agents (Claude Code, Codex, ...) their own short-lived OpenBao logins:
#   Kubernetes SA openbao/<agent>-ops  ->  auth/kubernetes/role/<agent>-ops  ->  policy agent-ops
# One role per agent, so the audit log shows which agent did what; one shared policy.
# Tokens last 15 min (30 min max) and nothing is stored. Agents log in with
# openbao/agent-login.sh <agent>.
#
# Run with an admin token (after `vault login -method=oidc`, or it prompts). Safe to re-run.
# Add an agent: add its ServiceAccount to agent-ops-sa.yaml and its name to AGENTS below.
#
# Scope: admin minus the dangerous endpoints (seal, root generation, rekey, raw storage,
# raft peers/snapshots, audit devices) and minus the obvious ways to raise its own rights
# (agent policy/roles, the admin policy, identity groups/entities, token roles, oidc auth).
# Treat it as roughly admin; kubectl cluster-admin already reaches as far.
# Revoke one agent: `vault delete auth/kubernetes/role/<agent>-ops` or delete its SA.
set -euo pipefail

AGENTS=(claude codex)

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

echo "==> ServiceAccounts"
kubectl apply -f "$(dirname "$0")/agent-ops-sa.yaml"

echo "==> Policy 'agent-ops'"
POLICY='# Everything...
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
path "sys/policy/agent-ops"             { capabilities = ["deny"] }
path "sys/policies/acl/agent-ops"       { capabilities = ["deny"] }
path "sys/policy/admin"                 { capabilities = ["deny"] }
path "sys/policies/acl/admin"           { capabilities = ["deny"] }
path "sys/policy/root"                  { capabilities = ["deny"] }
path "sys/policies/acl/root"            { capabilities = ["deny"] }
path "auth/kubernetes/config"           { capabilities = ["deny"] }
path "auth/oidc/*"                      { capabilities = ["deny"] }
path "sys/auth/oidc*"                   { capabilities = ["deny"] }
path "sys/auth/kubernetes*"             { capabilities = ["deny"] }
path "identity/group*"                  { capabilities = ["deny"] }
path "identity/entity*"                 { capabilities = ["deny"] }
path "auth/token/roles/*"               { capabilities = ["deny"] }
path "auth/token/create-orphan"         { capabilities = ["deny"] }
'
for a in "${AGENTS[@]}"; do
  POLICY+="path \"auth/kubernetes/role/${a}-ops\" { capabilities = [\"deny\"] }"$'\n'
done
api PUT sys/policies/acl/agent-ops "$(jq -nc --arg p "$POLICY" '{policy:$p}')"

api GET sys/auth | jq -e '.data["kubernetes/"]' >/dev/null || { echo "kubernetes auth not enabled"; exit 1; }
for a in "${AGENTS[@]}"; do
  echo "==> Kubernetes auth role '${a}-ops'"
  api POST "auth/kubernetes/role/${a}-ops" "$(jq -nc --arg sa "${a}-ops" '{
    bound_service_account_names: [$sa],
    bound_service_account_namespaces: ["openbao"],
    audience: "https://kubernetes.default.svc.cluster.local",
    token_policies: ["agent-ops"],
    token_ttl: "15m",
    token_max_ttl: "30m"
  }')"
done

# Old single-agent policy from the first version of this script
api DELETE sys/policies/acl/claude-ops >/dev/null || true

for a in "${AGENTS[@]}"; do
  echo -n "==> Test login as ${a}-ops: "
  JWT=$(kubectl -n openbao create token "${a}-ops" --duration 10m)
  curl -sSk "$ADDR/v1/auth/kubernetes/login" -H 'Content-Type: application/json' \
    -d "$(jq -nc --arg r "${a}-ops" --arg j "$JWT" '{role:$r,jwt:$j}')" \
    | jq -c '{errors, policies: .auth.policies, ttl: .auth.lease_duration}'
done
echo "Done."
