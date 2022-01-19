#!/usr/bin/env bash

# https://releases.hashicorp.com/vault/1.9.2/vault_1.9.2_windows_amd64.zip
# https://releases.hashicorp.com/vault/1.9.2/vault_1.9.2_linux_amd64.zip
# https://releases.hashicorp.com/vault/1.9.2/vault_1.9.2_linux_arm64.zip
# https://releases.hashicorp.com/vault/1.9.2/vault_1.9.2_darwin_amd64.zip
# https://releases.hashicorp.com/vault/1.9.2/vault_1.9.2_darwin_arm64.zip

vault auth enable kubernetes
vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc"
vault write auth/kubernetes/role/default policies="default" bound_service_account_names="*" bound_service_account_namespaces="*" ttl=24h
#export KUBE_TOKEN=$(oc exec -n mysql-test svc/mysql-test -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)
#curl -k --request POST --data '{"jwt": "'${KUBE_TOKEN}'", "role": "default"}' https://vault.wimsey.us/v1/auth/kubernetes/login

OIDC_CLIENT_ID=$(oc get -n k8s-deploy secret vault-oidc -o=jsonpath='{.data.oidc_client_id}' | base64 --decode)
OIDC_CLIENT_SECRET=$(oc get -n k8s-deploy secret vault-oidc -o=jsonpath='{.data.oidc_client_secret}' | base64 --decode)
OIDC_CLIENT_DISCOVERY_URL=$(oc get -n k8s-deploy secret vault-oidc -o=jsonpath='{.data.oidc_discovery_url}' | base64 --decode)
vault auth enable -path=Google oidc
vault write auth/Google/config -<<EOF
{
  "default_role": "default",
  "oidc_client_id": "$OIDC_CLIENT_ID",
  "oidc_discovery_url": "$OIDC_CLIENT_DISCOVERY_URL",
  "oidc_client_secret": "$OIDC_CLIENT_SECRET",
  "default_role": "default",
  "provider_config": {
      "provider": "gsuite",
      "gsuite_service_account": "/vault/gsuite-config/gsuite-config.json",
      "gsuite_admin_impersonate": "david@wimsey.us",
      "fetch_groups": true,
      "fetch_user_info": true,
      "groups_recurse_max_depth": 5
  }
}
EOF

vault write auth/Google/role/default user_claim="email" groups_claim="groups" oidc_scopes="openid,https://www.googleapis.com/auth/userinfo.email"  allowed_redirect_uris="https://vault.wimsey.us/ui/vault/auth/Google/oidc/callback" policies="default"

