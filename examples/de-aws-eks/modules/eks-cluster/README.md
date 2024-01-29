# EKS cluster for Document Engine

This module deploys AWS Elastic Kubernetes Service cluster to use with Document Engine. 
The cluster relies on a managed EC2 node group running on Bottlerocket platform. 

Additionally, the following tools are installed:

* [AWS for Flluent Bit](https://github.com/aws/aws-for-fluent-bit) to export container logs to AWS Cloudwatch
* [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) to expose Document Engine API and dashboard
