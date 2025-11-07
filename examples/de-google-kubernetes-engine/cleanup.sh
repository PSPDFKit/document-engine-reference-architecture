#!/bin/bash

# Document Engine on Google Kubernetes Engine - Cleanup script
# This script removes all resources created by setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables (must match setup.sh)
CLUSTER_NAME="document-engine-cluster"
ZONE="us-central1-a"

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

# Confirm deletion
confirm_deletion() {
    print_section "Document Engine on GKE - Cleanup"

    echo ""
    print_warning "This will DELETE the following resources:"
    echo "  • GKE cluster: $CLUSTER_NAME"
    echo "  • All Kubernetes workloads and data"
    echo "  • Load balancers"
    echo "  • Persistent disks"
    echo ""
    print_warning "This action CANNOT be undone!"
    echo ""

    read -p "Are you sure you want to continue? (yes/no): " confirmation

    if [ "$confirmation" != "yes" ]; then
        print_info "Cleanup cancelled"
        exit 0
    fi
}

# Delete GKE cluster
delete_gke_cluster() {
    print_section "Deleting GKE Cluster"

    if ! command_exists gcloud; then
        print_error "Google Cloud CLI (gcloud) is not installed"
        exit 1
    fi

    # Check if cluster exists
    if ! gcloud container clusters describe "$CLUSTER_NAME" --zone="$ZONE" &> /dev/null; then
        print_warning "Cluster '$CLUSTER_NAME' does not exist in zone '$ZONE'"
        print_info "Nothing to clean up"
        return 0
    fi

    print_info "Deleting GKE cluster: $CLUSTER_NAME"
    print_info "This may take a few minutes..."

    gcloud container clusters delete "$CLUSTER_NAME" \
        --zone="$ZONE" \
        --quiet

    print_info "✓ GKE cluster deleted"
}

# Verify cleanup
verify_cleanup() {
    print_section "Verifying Cleanup"

    print_info "Checking for remaining resources..."

    # Check for persistent disks
    DISKS=$(gcloud compute disks list --filter="zone:($ZONE)" --format="value(name)" 2>/dev/null | wc -l)
    if [ "$DISKS" -gt 0 ]; then
        print_warning "Found $DISKS persistent disk(s) in zone $ZONE"
        print_info "List them with: gcloud compute disks list --filter=\"zone:($ZONE)\""
        print_info "Delete them with: gcloud compute disks delete DISK_NAME --zone=$ZONE"
    else
        print_info "✓ No persistent disks found"
    fi

    # Check for forwarding rules (load balancers)
    RULES=$(gcloud compute forwarding-rules list --format="value(name)" 2>/dev/null | wc -l)
    if [ "$RULES" -gt 0 ]; then
        print_warning "Found $RULES forwarding rule(s)"
        print_info "List them with: gcloud compute forwarding-rules list"
    else
        print_info "✓ No forwarding rules found"
    fi

    print_info "✓ Cleanup verification complete"
}

# Display completion message
display_completion() {
    print_section "Cleanup Complete"

    echo ""
    echo "All Document Engine resources have been removed."
    echo ""
    print_info "If you see any warnings above, you may want to manually verify"
    print_info "and clean up those resources to avoid unexpected charges."
    echo ""
    echo "Check for any remaining resources:"
    echo "  gcloud compute disks list"
    echo "  gcloud compute forwarding-rules list"
    echo "  gcloud container clusters list"
    echo ""
}

# Main cleanup flow
main() {
    confirm_deletion
    delete_gke_cluster
    verify_cleanup
    display_completion
}

# Run main function
main
