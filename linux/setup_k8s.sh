#!/bin/bash

# This is a simple setup script that ensures prereqs for running k8s jobs on the OSSCI
# cluster are met.
set -e

echo "Starting Kubernetes setup..."

# Exit early if KUBECONFIG is not set to a valid path
if [ -z "$KUBECONFIG" ]; then
  echo "KUBECONFIG is not set or empty. Exiting"
  echo "Please download the authentication file from the AMD OSSCI confluence site and set KUBECONFIG env variable to the file path"
  echo "You will need this auth file to access the k8s cluster"
  exit 1
elif [ ! -f "$KUBECONFIG" ]; then
  echo "File $KUBECONFIG does not exit. Exiting"
  echo "Plese make sure the KUBECONFIG env variable is correctly set to the authentication file path"
  exit 1
else
  echo "KUBECONFIG is set to: $KUBECONFIG"
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
