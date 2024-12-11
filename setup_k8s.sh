#!/bin/bash

# This is a simple setup script that installs kubectl on your local machine.
set -e

echo "Starting Kubernetes setup..."

if [! -f "anon.conf" ]; then
  "Please download anon.conf from the AMD OSSCI confluence site to get started"
  exit 1
fi

echo "Downloading kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

echo "Downloading kubectl checksum..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

echo "Verifying the kubectl binary..."
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
if [ $? -ne 0 ]; then
  echo "Checksum verification failed. Exiting."
  exit 1
fi

echo "Installing kubectl..."
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

echo "Setup completed successfully!"
