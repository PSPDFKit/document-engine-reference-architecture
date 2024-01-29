#!/bin/bash

# Get Docker, just in case
apt-get install -y \
    git zip wget curl \
    snapd

snap install microk8s --classic --channel=latest/stable

microk8s enable ingress dns hostpath-storage helm
microk8s enable dashboard cert-manager

usermod -a -G microk8s ubuntu

echo "alias kubectl='microk8s kubectl'" >> /home/ubuntu/.bashrc
echo "alias helm='microk8s helm'" >> /home/ubuntu/.bashrc

# Kubectl completion
kubectl completion bash > /etc/bash_completion.d/kubectl

# Setting up
cd ~ubuntu

cat > document-engine_setup.sh <<ROOTEOF
${init_script_content}
ROOTEOF
chmod +x document-engine_setup.sh

wget -O document-engine.values.yaml \
    https://raw.githubusercontent.com/PSPDFKit/helm-charts/master/charts/document-engine/values.simple.yaml

cat > signing-service.Certificate.yaml <<ROOTEOF
${signing_service_certificate}
ROOTEOF

sudo -u ubuntu ./document-engine_setup.sh
