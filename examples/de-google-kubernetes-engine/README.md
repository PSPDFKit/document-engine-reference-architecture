# Document Engine example - Deploying to Google Kubernetes Engine (GKE)

- [About Google Kubernetes Engine](#about-google-kubernetes-engine)
- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [API usage examples](#api-usage-examples)
- [Cost considerations](#cost-considerations)
- [Cleanup](#cleanup)
- [Support](#support)
- [License](#license)
- [Contributing](#contributing)

> This example demonstrates a minimal installation of [Nutrient Document Engine](https://www.nutrient.io/guides/document-engine/) on Google Kubernetes Engine (GKE).

## About Google Kubernetes Engine

[Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine) is a managed Kubernetes service provided by Google Cloud Platform. It automates cluster management, scaling, and security updates.

This example uses GKE Standard clusters for maximum control and flexibility.

## Prerequisites

- [Google Cloud CLI (gcloud)](https://cloud.google.com/sdk/docs/install) - Command-line tool for GCP
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes command-line tool
- [Helm](https://helm.sh/docs/intro/install/) - Kubernetes package manager
- Active Google Cloud Platform account with billing enabled
- GCP project with Kubernetes Engine API and Compute Engine API enabled

## Getting started

1. Clone this repository and navigate to the example directory:

```shell
git clone https://github.com/PSPDFKit/document-engine-reference-architecture.git
cd document-engine-reference-architecture/examples/de-google-kubernetes-engine
```

2. Install and configure Google Cloud CLI:

```shell
# Install gcloud CLI (if not already installed)
# Visit: https://cloud.google.com/sdk/docs/install

# Initialize gcloud and authenticate
gcloud init

# Set your GCP project
gcloud config set project YOUR_PROJECT_ID

# Set your preferred region/zone
gcloud config set compute/zone us-central1-a
```

3. Enable required Google Cloud APIs:

```shell
gcloud services enable container.googleapis.com compute.googleapis.com
```

4. Run the automated setup script:

```shell
./setup.sh
```

The script will automatically:
- Create a GKE Standard cluster
- Install CloudNative-PG operator for PostgreSQL
- Install NGINX Ingress Controller
- Deploy Document Engine
- Display access information

This typically takes 10-15 minutes.

## API usage examples

Once Document Engine is running, you can use the [Document Engine API](https://www.nutrient.io/api/reference/document-engine/upstream/) to perform different operations. The setup script will display the external IP address of your deployment.

Replace `EXTERNAL_IP` in the examples below with your actual external IP address.

### Upload a document

Upload the sample PDF document:

```shell
curl --request POST \
  --url http://EXTERNAL_IP/api/documents \
  --header 'Authorization: Token token=secret' \
  --form 'pdf-file-from-multipart=@sample.pdf' \
  --form 'instructions={"parts":[{"file":"pdf-file-from-multipart"}],"actions":[],"output":{"type":"pdf","metadata":{"title":"Test Document","author":"API User"}}}'
```

The response will include a `document_id` that you can use in the following examples.

### List documents

```shell
curl --request GET \
  --url http://EXTERNAL_IP/api/documents \
  --header 'Authorization: Token token=secret'
```

### Get document information

Replace `DOCUMENT_ID` with the actual document ID from the upload response:

```shell
curl --request GET \
  --url http://EXTERNAL_IP/api/documents/DOCUMENT_ID/document_info \
  --header 'Authorization: Token token=secret'
```

### Extract text

Extract text from all pages:

```shell
curl --request GET \
  --url http://EXTERNAL_IP/api/documents/DOCUMENT_ID/pages/text \
  --header 'Authorization: Token token=secret'
```

### Download PDF

Download the processed PDF:

```shell
curl --request GET \
  --url http://EXTERNAL_IP/api/documents/DOCUMENT_ID/pdf \
  --header 'Authorization: Token token=secret' \
  --output downloaded-document.pdf
```

## Cost considerations

Running this example on GKE incurs costs. Estimated costs with the default configuration:

**Hourly costs** (approximate, us-central1 region):
- GKE cluster management: $0.10/hour
- Compute nodes (3 × e2-standard-4): ~$0.40/hour
- Load balancer: ~$0.025/hour + data transfer
- Persistent disk storage (10GB): ~$0.0002/hour

**Total**: ~$0.50-0.60/hour or ~$12-15/day

**Cost optimization tips**
- Delete the cluster when not in use (see [Cleanup](#cleanup))
- Use smaller machine types for testing (for example, e2-standard-2)
- Reduce the number of nodes to 1 for development
- Consider Spot VMs for non-production workloads
- Use regional pricing comparisons: [GCP pricing calculator](https://cloud.google.com/products/calculator)

**Regional considerations**
- This example uses `us-central1` which typically has competitive pricing
- For lower latency, deploy to a region closer to your users:
  - Europe: `europe-west1`, `europe-west4`
  - Asia: `asia-southeast1`, `asia-east1`
  - See all regions: [GCP regions](https://cloud.google.com/about/locations)

## Cleanup

To remove all resources and stop incurring costs:

```shell
./cleanup.sh
```

The cleanup script will delete the cluster and check for any remaining resources. If persistent disks are left behind (this is expected behavior for Kubernetes PersistentVolumes), the script will warn you and provide commands to clean them up manually.

Or manually:

```shell
# Delete the GKE cluster
gcloud container clusters delete document-engine-cluster --zone=us-central1-a

# Verify all resources are deleted
gcloud compute disks list
gcloud compute forwarding-rules list

# If any persistent disks remain, delete them
gcloud compute disks delete DISK_NAME --zone=us-central1-a
```

> Persistent disks from PostgreSQL may not be automatically deleted when the cluster is removed. Always verify that all resources are deleted to avoid unexpected charges.

## Support

Nutrient offers support for customers with an active SDK license via [Nutrient Support](https://www.nutrient.io/support/request/).

Are you [evaluating our SDK](https://www.nutrient.io/sdk/try/)? That’s great, we’re happy to help out! To make sure this is fast, please use a work email and have someone from your company fill out our [sales form](https://www.nutrient.io/contact-sales/).

## License

This project is licensed under the BSD license. See the LICENSE file for more details.

## Contributing

Please ensure you have signed our CLA so that we can accept your contributions.
