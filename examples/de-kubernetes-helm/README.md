# Document Engine example - Deploying to the locally configured Kubernetes

- [Document Engine example - Deploying to the locally configured Kubernetes](#document-engine-example---deploying-to-the-locally-configured-kubernetes)
  - [Introduction and prerequisites](#introduction-and-prerequisites)
  - [Deployment](#deployment)
    - [DNS resolution override](#dns-resolution-override)
  - [Accessing the deployed components](#accessing-the-deployed-components)
  - [Cleanup](#cleanup)
  - [License](#license)
  - [Support, Issues and License Questions](#support-issues-and-license-questions)

> [!WARNING]
> This example is provided purely for educational purpose. 
> It exposes deployed Document Engine publicly without TLS encryption and other protective measures. 
> It should never be deployed in production configuration or reused as an unchanged building block. 

## Introduction and prerequisites

This example demonstrates deploying Document Engine using Helm on Kubernetes. An easy way to run Kubernetes locally is [Docker Desktop](https://docs.docker.com/desktop/kubernetes/). On Linux, [microk8s](https://microk8s.io/) is a good option.

We will assume that a Kubernetes cluster is available and locally configured, 
[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) and [Helm](https://helm.sh/docs/intro/install/) are installed.

The deployed components include:

* Document Engine installed with a Helm chart, with very basic defaults
* An [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) resource to expose Document Engine publicly
* Some additional components for further experimentation:
  * Self-signed private Certificate Authority to sign certificates
  * [Cert-manager](https://cert-manager.io/) to make use of it

## Deployment

Clone this repository.

Install dependencies:

```shell
terraform init -upgrade
```

First, setup a [Kubernetes context](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/). 

Prepare Terraform environment by setting environment variables for the Kubernetes context and, optionally, the desired hostname:

```shell
export TF_VAR_kubernetes_config_context="docker-desktop"
export TF_VAR_document_engine_hostname="document-engine.pspdfkit.local"
```

> [!NOTE]
> Unless you have condifured DNS resolution for the hostname, it will require manual override in the local resolver to access.

Next, generate a JWT key pair using the `generate-jwt-pair.sh` script

```shell
# Run from within examples/de-kubernetes-helm

../../scripts/generate-jwt-pair.sh
```

Finally, examine the plan and apply it:

```shell
terraform plan
terraform apply
```

### DNS resolution override

To make local resolver point at the installed assets, an override may be required. 

On Linux and macOS, the quickest way to do that is to edit `/etc/hosts` file:

```
...
127.0.0.1 document-engine.pspdfkit.local
...
```

## Accessing the deployed components

> [!NOTE]
> After Terraform plan is applied, it will take several minutes for the script to finish setting up, 
> so consider giving it 5-10 minutes before trying the next steps. 

Checking that the Document Engine responds:

```shell
curl http://<hostname>
```

The output should look like:

```
PSPDFKit Document Engine 1.0.0 is up and running.
```

To access Document Engine dashboard from a web browser, follow the url `http://<hostname>/dashboard`, username is `admin` and password is `admin`.

To examine the installation: 

```shell
kubectl get pods -n pspdfkit-document-engine
```

will give output like: 

```
NAME                               READY   STATUS    RESTARTS   AGE
document-engine-postgresql-0       1/1     Running   0          53m
document-engine-55b6b47bcf-64dts   1/1     Running   0          53m
```

## Cleanup

To remove the resources created above: 

```shell
terraform destroy
```

## License

This software is licensed under a [modified BSD license](LICENSE).

## Support, Issues and License Questions

PSPDFKit offers support via https://pspdfkit.com/support/request/

Are you [evaluating our SDK](https://pspdfkit.com/try/)? That's great, we're happy to help out! To make sure this is fast, please use a work email and have someone from your company fill out our sales form: https://pspdfkit.com/sales/

