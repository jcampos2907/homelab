pipeline {
  agent any

  environment {
    ARGOCD_SERVER = "100.113.56.193"
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
              -X POST "https://$ARGOCD_SERVER/api/v1/applications/homelab-root/refresh?hard=true" \
              -H "Content-Type: application/json" \
              --data '{}'
          '''
        }
      }
    }
  }
}
