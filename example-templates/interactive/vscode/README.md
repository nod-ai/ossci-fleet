# Interactive VSCode Session

The OSSCI Fleet aims to provide central infrastructure to enable developer access to support AIG’s GPU software development, leveraging our in-house GPU as a Service (GPUaaS) platform.
This guide covers how to start an interactive vscode session.

## Prerequisites

If you haven't already, please refer to [Kubernetes Setup](https://github.com/nod-ai/ossci-fleet/blob/main/README.md#step-1-kubernetes-setup) instructions to onboard onto an OSSCI cluster.

If you are planning to use a remote host to start this interactive VSCode session, please ssh tunnel so that the 
web server that gets started is available on your local machine:

```bash
ssh -L 8000:localhost:8000 user@hostname
```

Please follow [PVC Provisioning Instructions](https://amd.atlassian.net/wiki/spaces/SHARK/pages/1147359911/How+To+Create+Persistent+Volume+Claims) to create a Persistent Volume Claim for persistent storage.

## VSCode Setup

Feel free to edit [vscode template](./vscode-session-pvc.yml) if you would like to change the docker image or number of gpus that the VSCode interactive session comes up with.

To start a VSCode interactive session in your assigned kubernetes namespace and PVC (Persistent Volume Claim) 
that you created for persistent storage:

```bash
git clone git@github.com:nod-ai/ossci-fleet.git
cd ossci-fleet/example-templates/interactive/vscode
./run-vscode-interactive <assigned-k8s-namespace> <pvc-name>
```

Once started, access VSCode at: http://localhost:8000

The script automatically makes your persistent storage directory available at `/ossci`. Please make sure to use this directory for your development, so all your work and data is persisted.
