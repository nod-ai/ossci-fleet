# Interactive VSCode Session

The OSSCI Fleet aims to provide central infrastructure to enable developer access to support AIG’s GPU software development, leveraging our in-house GPU as a Service (GPUaaS) platform.
This guide covers how to start an interactive vscode session.

## Prerequisites

If you haven't already, please refer to [Kubernetes Setup](https://github.com/nod-ai/ossci-fleet/blob/main/README.md#step-1-kubernetes-setup) instructions to onboard onto an OSSCI cluster.

Please follow [PVC Provisioning Instructions](https://amd.atlassian.net/wiki/spaces/SHARK/pages/1147359911/How+To+Create+Persistent+Volume+Claims) to create a Persistent Volume Claim for persistent storage.

Update [config.json](./config.json) to your assigned namespace, PVC, and path to public ssh key. The SSH key is the public ssh key of the host that you want to use to remote connect with VSCode or ssh directly in terminal to the pod.

## VSCode Setup

You can launch a VSCode interactive environment inside your assigned Kubernetes namespace with your existing Persistent Volume Claim (PVC).
The environment supports two modes — browser-based (web) and SSH-based (ssh).

### SSH Mode

Runs a VSCode environment accessible via the VS Code Remote SSH extension.
The script forwards the pod’s SSH port (22) to your local machine (2222).

Add the following entry to your local `~/.ssh/config`:

```bash
Host ossci
  HostName 127.0.0.1
  User ossci
  Port 2222
  IdentityFile \Users\esaimana\.ssh\id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

You can connect either via the VS Code Remote SSH extension:

Remote-SSH: Connect to Host...
→ ossci


or directly from your terminal:

ssh ossci

If you are planning to use a remote host to start this interactive VSCode session, please ssh tunnel so that the ssh session that gets started is available on your local machine:

```bash
ssh -L 2222:localhost:2222 user@hostname
```

### Web Mode

Runs a browser-accessible VSCode server inside a pod.
Once ready, the script automatically forwards port 9000 from the pod to your local port 8000.

Access it in your browser at:

http://localhost:8000

If you are planning to use a remote host to start this interactive VSCode session, please ssh tunnel so that the ssh session that gets started is available on your local machine:

```bash
ssh -L 8000:localhost:8000 user@hostname
```

### Usage

```bash
git clone git@github.com:nod-ai/ossci-fleet.git
cd ossci-fleet/example-templates/interactive/vscode
./run-vscode-interactive.sh <web|ssh>
```

The script reads your configuration from [config.json](./config.json) (namespace, PVC, SSH key) and automatically deploys the appropriate pod in your namespace.

Feel free to edit [vscode ssh](./vscode-session-ssh.yml) or [vscode web](./vscode-session-web.yml) templates if you would like to change the docker image or number of gpus that the VSCode interactive session comes up with.

#### Install ROCm

```bash
mkdir therock-tarball && cd therock-tarball
wget https://therock-nightly-tarball.s3.us-east-2.amazonaws.com/therock-dist-linux-gfx94X-dcgpu-7.0.0rc20250729.tar.gz
mkdir install
tar -xf *.tar.gz -C install
```

Find the latest tarballs for all architectures here: https://therock-nightly-tarball.s3.amazonaws.com/index.html

Add the following to your `.bashrc` or `.zshrc`:

```bash
export PATH=$HOME/therock-tarball/bin:$PATH
export LD_LIBRARY_PATH=$HOME/therock-tarball/lib
```

If you would like to use TheRock python packages or build from source, please refer to [therock.md](../the-rock/therock.md)

### Persistent Storage

Your home directory (/home/ossci) inside the VSCode environment is mounted from your PVC, ensuring that all your code, configurations, and data persist across sessions.
Use this directory for all your development work.
