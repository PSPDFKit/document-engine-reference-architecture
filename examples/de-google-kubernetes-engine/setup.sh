#!/bin/bash

# Document Engine on Google Kubernetes Engine - Automated setup script
# This script automates the deployment of Document Engine on GKE

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
CLUSTER_NAME="document-engine-cluster"
ZONE="us-central1-a"
MACHINE_TYPE="e2-standard-4"
NUM_NODES=3
NAMESPACE="document-engine"

# Print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_section "Checking Prerequisites"

    if ! command_exists gcloud; then
        print_error "Google Cloud CLI (gcloud) is not installed."
        print_info "Install it from: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    print_info "✓ Google Cloud CLI is installed"

    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Install it with: brew install kubectl"
        print_info "Or install via gcloud: gcloud components install kubectl"
        exit 1
    fi
    print_info "✓ kubectl is installed"

    if ! command_exists helm; then
        print_error "Helm is not installed. Install it with: brew install helm"
        exit 1
    fi
    print_info "✓ Helm is installed"

    # Check if user is authenticated with gcloud
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        print_error "Not authenticated with Google Cloud. Run: gcloud auth login"
        exit 1
    fi
    print_info "✓ Google Cloud authentication configured"

    # Get current project
    PROJECT_ID=$(gcloud config get-value project 2> /dev/null)
    if [ -z "$PROJECT_ID" ]; then
        print_error "No GCP project selected. Run: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
    print_info "✓ Using GCP project: $PROJECT_ID"
}

# Enable required Google Cloud APIs
enable_apis() {
    print_section "Enabling Required Google Cloud APIs"

    print_info "Enabling Kubernetes Engine API and Compute Engine API..."
    gcloud services enable container.googleapis.com compute.googleapis.com --quiet
    print_info "✓ Required APIs enabled"
}

# Create GKE cluster
create_gke_cluster() {
    print_section "Creating GKE Standard Cluster"

    # Check if cluster already exists
    if gcloud container clusters describe "$CLUSTER_NAME" --zone="$ZONE" &> /dev/null; then
        print_warning "Cluster '$CLUSTER_NAME' already exists, skipping creation..."
        print_info "Getting cluster credentials..."
        gcloud container clusters get-credentials "$CLUSTER_NAME" --zone="$ZONE" --quiet
        return 0
    fi

    print_info "Creating GKE cluster: $CLUSTER_NAME"
    print_info "Zone: $ZONE"
    print_info "Machine type: $MACHINE_TYPE"
    print_info "Number of nodes: $NUM_NODES"
    print_info "This will take approximately 5-10 minutes..."

    gcloud container clusters create "$CLUSTER_NAME" \
        --zone="$ZONE" \
        --machine-type="$MACHINE_TYPE" \
        --num-nodes="$NUM_NODES" \
        --disk-size=50 \
        --disk-type=pd-standard \
        --enable-autorepair \
        --enable-autoupgrade \
        --no-enable-cloud-logging \
        --no-enable-cloud-monitoring \
        --quiet

    print_info "✓ GKE cluster created successfully"

    # Get cluster credentials
    print_info "Configuring kubectl..."
    gcloud container clusters get-credentials "$CLUSTER_NAME" --zone="$ZONE" --quiet
    print_info "✓ kubectl configured"
}

# Install CloudNative-PG Operator
install_cloudnative_pg() {
    print_section "Installing CloudNative-PG Operator"

    helm repo add cnpg https://cloudnative-pg.github.io/charts 2>/dev/null || true
    helm repo update

    if helm list -n cnpg-system | grep -q cnpg; then
        print_info "CloudNative-PG is already installed, skipping..."
    else
        print_info "Installing CloudNative-PG Operator..."
        helm upgrade --install cnpg \
            --namespace cnpg-system \
            --create-namespace \
            cnpg/cloudnative-pg

        print_info "Waiting for CloudNative-PG to be ready..."
        kubectl wait --for=condition=Available \
            deployment/cnpg-cloudnative-pg \
            -n cnpg-system \
            --timeout=300s

        print_info "✓ CloudNative-PG Operator installed"
    fi
}

# Install NGINX Ingress Controller
install_nginx_ingress() {
    print_section "Installing NGINX Ingress Controller"

    if kubectl get namespace ingress-nginx &> /dev/null; then
        print_info "NGINX Ingress Controller is already installed, skipping..."
    else
        print_info "Installing NGINX Ingress Controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

        print_info "Waiting for NGINX Ingress Controller to be ready..."
        kubectl -n ingress-nginx wait \
            --for=condition=Available \
            deployment/ingress-nginx-controller \
            --timeout=300s
        print_info "✓ NGINX Ingress Controller installed"
    fi

    # Wait for load balancer to get external IP
    print_info "Waiting for Load Balancer to get external IP..."
    for i in {1..30}; do
        EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ ! -z "$EXTERNAL_IP" ]; then
            print_info "✓ External IP assigned: $EXTERNAL_IP"
            return 0
        fi
        echo "   Waiting... ($i/30)"
        sleep 10
    done

    print_warning "Timeout waiting for external IP, but continuing..."
}

# Install Document Engine
install_document_engine() {
    print_section "Installing Document Engine"

    helm repo add nutrient https://pspdfkit.github.io/helm-charts 2>/dev/null || true
    helm repo update

    print_info "Installing Document Engine with Helm..."
    helm upgrade --install \
        --namespace "$NAMESPACE" \
        --create-namespace \
        document-engine nutrient/document-engine \
        -f document-engine.values.yaml

    print_info "✓ Document Engine installation initiated"
}

# Wait for Document Engine to be ready
wait_for_document_engine() {
    print_section "Waiting for Document Engine to be Ready"

    print_info "This may take a few minutes..."

    # Wait for database cluster to be ready
    print_info "Waiting for PostgreSQL cluster..."
    kubectl wait --for=condition=Ready \
        cluster/document-engine-postgres \
        -n "$NAMESPACE" \
        --timeout=300s 2>/dev/null || true

    # Wait for Document Engine pods to be ready
    print_info "Waiting for Document Engine pods..."
    kubectl wait --for=condition=Ready \
        pod -l app.kubernetes.io/name=document-engine \
        -n "$NAMESPACE" \
        --timeout=300s

    print_info "✓ Document Engine is ready"
}

# Display access information
display_info() {
    print_section "Installation Complete!"

    # Get external IP
    EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

    echo ""
    echo "Document Engine is now running on your GKE cluster."
    echo ""
    echo "Access Information:"
    echo "  API Endpoint:  http://$EXTERNAL_IP"
    echo "  Dashboard:     http://$EXTERNAL_IP/dashboard"
    echo "  Dashboard User: admin"
    echo "  Dashboard Pass: admin"
    echo ""
    echo "API Authentication:"
    echo "  Use header: Authorization: Token token=secret"
    echo ""
    echo "Test the installation:"
    echo "  curl http://$EXTERNAL_IP/healthcheck"
    echo ""
    echo "Upload a sample document:"
    echo "  curl --request POST \\"
    echo "    --url http://$EXTERNAL_IP/api/documents \\"
    echo "    --header 'Authorization: Token token=secret' \\"
    echo "    --form 'pdf-file-from-multipart=@sample.pdf' \\"
    echo "    --form 'instructions={\"parts\":[{\"file\":\"pdf-file-from-multipart\"}],\"actions\":[],\"output\":{\"type\":\"pdf\"}}'"
    echo ""
    echo "View logs:"
    echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=document-engine"
    echo ""
    echo "Cluster management:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo "  kubectl get all -n $NAMESPACE"
    echo ""
    print_warning "IMPORTANT: This cluster incurs costs (~\$0.50/hour)."
    print_warning "Run ./cleanup.sh when finished to delete all resources."
    echo ""
    echo "For more information, see the README.md file."
    echo ""
}

# Main installation flow
main() {
    print_section "Document Engine on Google Kubernetes Engine - Setup"

    check_prerequisites
    enable_apis
    create_gke_cluster
    install_cloudnative_pg
    install_nginx_ingress
    install_document_engine
    wait_for_document_engine
    display_info
}

# Run main function
main
