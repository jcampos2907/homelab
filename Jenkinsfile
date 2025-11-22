pipeline {
  agent any

  environment {
    ARGOCD_SERVER = "https://argocd-server.argocd.svc.cluster.local"
  }

  stages {
    stage("Argo Sync via API") {
      steps {
        withCredentials([string(credentialsId: 'argocd-token', variable: 'ARGOCD_AUTH_TOKEN')]) {
          sh '''
            set -euo pipefail
            # refresh (hard) so Argo re-pulls Git
            curl -sk \
              -H "Authorization: Bearer $ARGOCD_AUTH_TOKEN" \
              -X POST "$ARGOCD_SERVER/api/v1/applications/homelab-root/refresh?hard=true" \
              -H "Content-Type: application/json" \
              --data '{}'
          '''
        }
      }
    }
  }
}
