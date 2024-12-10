#!/bin/bash
set -e

echo "Starting Kubernetes setup..."

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

echo "Installing wget..."
sudo apt-get update -y
sudo apt-get install wget -y

echo "Downloading anon.conf..."
wget -q https://sharkpublic.blob.core.windows.net/sharkpublic/ossci/anon.conf

echo "Setup completed successfully!"
