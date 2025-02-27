#!/bin/bash
# This is a simple setup script that ensures prereqs for running k8s jobs on the OSSCI
# cluster are met.
set -e
echo "Starting Kubernetes setup..."
if [ ! -f "anon.conf" ]; then
  echo "Please download anon.conf from the AMD OSSCI confluence site to get started"
  echo "You will need this auth file to access the k8s cluster"
  exit 1
fi
echo "Downloading kubectl..."
# Added -k flag to bypass SSL certificate verification
curl -k -LO "https://dl.k8s.io/release/$(curl -k -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
echo "Downloading kubectl checksum..."
# Added -k flag to bypass SSL certificate verification
curl -k -LO "https://dl.k8s.io/release/$(curl -k -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "Verifying the kubectl binary..."
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
if [ $? -ne 0 ]; then
  echo "Checksum verification failed. Exiting."
  exit 1
fi
echo "Installing kubectl..."
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
echo "Setup completed successfully!"
