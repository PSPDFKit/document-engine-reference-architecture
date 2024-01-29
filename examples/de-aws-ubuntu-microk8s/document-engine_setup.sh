# !/bin/bash

set -e

# Self-signed Certificate Authority

mkdir -p ./tls
openssl genrsa -out tls/test-ca.key 2048
openssl req -x509 -new -nodes -key tls/test-ca.key \
  -subj "/CN=DEMO CA 1" -days 90 -reqexts v3_req -extensions v3_ca \
  -out tls/test-ca.cert

microk8s kubectl create secret tls local-ca-key-pair \
  --cert=tls/test-ca.cert --key=tls/test-ca.key \
  --namespace=cert-manager

cat > tls/local.ClusterIssuer.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
    name: local-ca-issuer
spec:
    ca:
        secretName: local-ca-key-pair
EOF

microk8s kubectl apply -f tls/local.ClusterIssuer.yaml

# Document Engine

microk8s kubectl create namespace pspdfkit
microk8s kubectl config set-context --current --namespace=pspdfkit

microk8s helm repo add pspdfkit https://pspdfkit.github.io/helm-charts
microk8s helm repo update

microk8s kubectl apply -f signing-service.Certificate.yaml

microk8s helm upgrade --install -n pspdfkit \
  document-engine pspdfkit/document-engine \
  -f document-engine.values.yaml \
  --set pspdfkit.signingService.url=http://signing-service.pspdfkit.svc.cluster.local:80

