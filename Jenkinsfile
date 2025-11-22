pipeline {
  agent any

  environment {
    ARGOCD_SERVER = "https://argocd-server.argocd.svc.cluster.local"
  }

  stages {
    stage("Argo Hard Refresh") {
  steps {
    withCredentials([string(credentialsId: 'argocd-token', variable: 'ARGOCD_AUTH_TOKEN')]) {
      sh '''
        set -euo pipefail
        ARGO="https://argocd-server.argocd.svc.cluster.local"

        echo "Hard-refreshing homelab-root..."
        code=$(curl -skL -o /tmp/refresh.json -w "%{http_code}" \
          -H "Authorization: Bearer $ARGOCD_AUTH_TOKEN" \
          "$ARGO/api/v1/applications/homelab-root?refresh=hard")

        echo "refresh_http=$code"
        cat /tmp/refresh.json | head -c 300; echo

        if [ "$code" -lt 200 ] || [ "$code" -ge 300 ]; then
          echo "Hard refresh failed"
          exit 1
        fi
      '''
    }
  }
}
  }
}
