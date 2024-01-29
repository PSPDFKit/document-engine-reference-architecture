# Document Engine example - deploying to a virtual machine on AWS using a single node Kubernetes cluster

- [Document Engine example - deploying to a virtual machine on AWS using a single node Kubernetes cluster](#document-engine-example---deploying-to-a-virtual-machine-on-aws-using-a-single-node-kubernetes-cluster)
  - [Deployment](#deployment)
  - [Accessing the deployed components](#accessing-the-deployed-components)
  - [Cleanup](#cleanup)
  - [License](#license)
  - [Support, Issues and License Questions](#support-issues-and-license-questions)

> [!WARNING]
> This example is provided purely for educational purpose. 
> It exposes deployed Document Engine publicly without TLS encryption and other protective measures. 
> It should never be deployed in production configuration or reused as an unchanged building block. 

This example demonstrates provisioning a virtual machine (EC2 instance) running Ubuntu Linux in AWS and setting up Kubernetes cluster on it to use for Document Engine installation.

The deployed components include:

* A virtual machine in AWS EC2 running Ubuntu Server
* [MicroK8s](https://microk8s.io/), Kubernetes cluster implementation
* Document Engine installed with a Helm chart, with very basic defaults
* An [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) resource to expose Document Engine publicly
* Some additional components for further experimentation:
  * Self-signed private Certificate Authority to sign certificates
  * [Cert-manager](https://cert-manager.io/) to make use of it

## Deployment

Clone this repository.

If you don't have an SSH key to use, make one:

```shell
ssh-keygen -t ed25519 -C "your_email@example.com" -f $HOME/.ssh/id_ed25519_demo
```

First, setup an AWS profile using the AWS configuration wizard with `aws configure --profile document-engine-example`. Then prepare Terraform environment by setting the AWS profile and (optionally) region to use. This can be done by setting environment variables:

```shell
export TF_VAR_aws_profile_name="document-engine-example"
export TF_VAR_aws_region="eu-north-1"
export TF_VAR_vm_public_key="$HOME/.ssh/id_ed25519_demo.pub"
```

Install dependencies:

```shell
terraform init -upgrade
```

Examine the plan and apply it:

```shell
terraform plan
terraform apply
```

The output will contain public IP and DNS name of the deployed instance:

```
Outputs:

vm_id = "..."
vm_public_dns = "..."
vm_public_ip = "..."
```

## Accessing the deployed components

> [!NOTE]
> After Terraform plan is applied, it will take several minutes for the script to finish setting up, 
> so consider giving it 5-15 minutes before trying the next steps. 

Checking that the Document Engine responds:

```shell
curl http://<VM public IP>
```

The output should look like:

```
PSPDFKit Document Engine 1.0.0 is up and running.
```

To access Document Engine dashboard from a web browser, follow the url `http://<VM public IP>/dashboard`, username is `admin` and password is `admin`.

If you wish to explore further, you can log into the VM: 

```shell
ssh -i $HOME/.ssh/id_ed25519_demo ubuntu@<VM public IP>
```

From within, `kubectl` can be used, e.g.:

```shell
kubectl get pods
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

