#!/bin/bash

# Installs Document Engine behind Envoy Gateway, with access logs that identify
# every client, on the Kubernetes cluster of your current kubectl context.
#
# Usage: ./setup.sh
#
# Set KUBE_CONTEXT to target a cluster other than the current kubectl context.

set -euo pipefail

cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ENVOY_GATEWAY_VERSION=v1.5.0
DOCUMENT_ENGINE_CHART_VERSION=8.7.0
CLOUDNATIVE_PG_CHART_VERSION=0.29.1
DOCUMENT_ID=client-tracing-demo

kubectl_args=()
helm_args=()
if [ -n "${KUBE_CONTEXT:-}" ]; then
    kubectl_args+=(--context "$KUBE_CONTEXT")
    helm_args+=(--kube-context "$KUBE_CONTEXT")
fi

k() {
    kubectl "${kubectl_args[@]}" "$@"
}

h() {
    helm "${helm_args[@]}" "$@"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

check_prerequisites() {
    print_section "Checking prerequisites"

    for command in kubectl helm jq openssl curl; do
        if ! command -v "$command" > /dev/null 2>&1; then
            print_error "$command is not installed."
            exit 1
        fi
        print_info "✓ $command is installed"
    done

    if ! k cluster-info > /dev/null 2>&1; then
        print_error "No Kubernetes cluster is reachable. Check your kubectl context, or set KUBE_CONTEXT."
        exit 1
    fi
    print_info "✓ Using kubectl context: ${KUBE_CONTEXT:-$(kubectl config current-context)}"
}

install_cloudnative_pg() {
    print_section "Installing the CloudNative-PG operator"

    helm repo add cnpg https://cloudnative-pg.github.io/charts > /dev/null 2>&1 || true
    helm repo update cnpg > /dev/null

    h upgrade --install cnpg cnpg/cloudnative-pg \
        --version "$CLOUDNATIVE_PG_CHART_VERSION" \
        --namespace cnpg-system \
        --create-namespace \
        --wait
    print_info "✓ CloudNative-PG is ready"
}

install_envoy_gateway() {
    print_section "Installing Envoy Gateway"

    h upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
        --version "$ENVOY_GATEWAY_VERSION" \
        --namespace envoy-gateway-system \
        --create-namespace \
        --wait
    print_info "✓ Envoy Gateway is ready"
}

create_jwt_keys() {
    print_section "Creating the JWT key pair"

    if [ -f keys/jwt-private.pem ]; then
        print_info "keys/jwt-private.pem already exists, keeping it"
        return
    fi

    mkdir -p keys
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out keys/jwt-private.pem 2> /dev/null
    openssl rsa -in keys/jwt-private.pem -pubout -out keys/jwt-public.pem 2> /dev/null
    print_info "✓ Wrote keys/jwt-private.pem and keys/jwt-public.pem"
}

install_document_engine() {
    print_section "Installing Document Engine"

    k create namespace document-engine --dry-run=client -o yaml | k apply -f -
    k apply -f gateway.yaml

    helm repo add nutrient https://pspdfkit.github.io/helm-charts > /dev/null 2>&1 || true
    helm repo update nutrient > /dev/null

    h upgrade --install document-engine nutrient/document-engine \
        --version "$DOCUMENT_ENGINE_CHART_VERSION" \
        --namespace document-engine \
        -f document-engine.values.yaml \
        --set-file apiAuth.jwt.publicKey=keys/jwt-public.pem

    print_info "Waiting for the database..."
    k wait --for=condition=Ready cluster/document-engine-postgres \
        -n document-engine --timeout=300s 2> /dev/null || true

    print_info "Waiting for Document Engine..."
    k wait --for=condition=Ready pod -l app.kubernetes.io/name=document-engine \
        -n document-engine --timeout=600s

    print_info "Waiting for the Envoy proxy..."
    k wait --for=condition=Available deployment \
        -l gateway.envoyproxy.io/owning-gateway-name=document-engine \
        -n envoy-gateway-system --timeout=300s

    print_info "✓ Document Engine is ready"
}

gateway_service() {
    k get service -n envoy-gateway-system \
        -l gateway.envoyproxy.io/owning-gateway-name=document-engine \
        -o jsonpath='{.items[0].metadata.name}'
}

upload_sample_document() {
    print_section "Uploading the sample document"

    local port=18080
    k port-forward -n envoy-gateway-system "service/$(gateway_service)" "$port:80" > /dev/null 2>&1 &
    local port_forward_pid=$!
    disown "$port_forward_pid"
    trap 'kill $port_forward_pid 2> /dev/null || true' RETURN

    for _ in $(seq 1 30); do
        curl -s -o /dev/null "http://localhost:$port/healthcheck" && break
        sleep 1
    done

    local status
    status=$(curl -s -o /dev/null -w '%{http_code}' \
        -H "Authorization: Token token=secret" \
        "http://localhost:$port/api/documents/$DOCUMENT_ID/properties")
    if [ "$status" = "200" ]; then
        print_info "Document $DOCUMENT_ID already exists, keeping it"
    else
        curl -s --fail -X POST "http://localhost:$port/api/documents" \
            -H "Authorization: Token token=secret" \
            -F "document_id=$DOCUMENT_ID" \
            -F "file=@sample.pdf" > /dev/null
        print_info "✓ Uploaded sample.pdf as $DOCUMENT_ID"
    fi

    ./mint-jwt.sh --write "$DOCUMENT_ID" alice Alice > /dev/null
    ./mint-jwt.sh --write "$DOCUMENT_ID" bob Bob > /dev/null
    print_info "✓ Wrote viewer tokens for alice and bob (valid for one hour)"
}

display_info() {
    print_section "Installation complete"

    local context_prefix=""
    if [ -n "${KUBE_CONTEXT:-}" ]; then
        context_prefix="KUBE_CONTEXT=$KUBE_CONTEXT "
    fi

    cat << EOF

1. Make Document Engine reachable on http://localhost:8080 (keep this running):

     kubectl ${kubectl_args[*]} port-forward -n envoy-gateway-system service/$(gateway_service) 8080:80

2. Serve the viewer page (keep this running):

     python3 -m http.server 4300 --directory viewer

3. Open two viewers as different users:

     http://localhost:4300/?user=alice
     http://localhost:4300/?user=bob

4. Optionally, add an iOS and a Web client with scripted changes and rejections:

     ${context_prefix}./simulate-clients.sh

5. See which client sent each sync, and what Document Engine did with it:

     ${context_prefix}./trace-clients.sh
     ${context_prefix}./trace-clients.sh --record <annotation-id>

EOF
}

check_prerequisites
install_cloudnative_pg
install_envoy_gateway
create_jwt_keys
install_document_engine
upload_sample_document
display_info
