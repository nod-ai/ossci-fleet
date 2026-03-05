# Interactive VSCode Session

The OSSCI Fleet aims to provide central infrastructure to enable developer access to support AIG's GPU software development, leveraging our in-house GPU as a Service (GPUaaS) platform.
This guide covers how to start an interactive vscode session.

## Prerequisites

If you haven't already, please refer to [Kubernetes Setup](https://github.com/nod-ai/ossci-fleet/blob/main/README.md#step-1-kubernetes-setup) instructions to onboard onto an OSSCI cluster.

Please follow [PVC Provisioning Instructions](https://amd.atlassian.net/wiki/spaces/AMD-SHARK/pages/1147359911/How+To+Create+Persistent+Volume+Claims) to create a Persistent Volume Claim for persistent storage.

Update [config.json](./config.json) to your assigned namespace, PVC, and path to public ssh key. The SSH key is the public ssh key of the host that you want to use to remote connect with VSCode or ssh directly in terminal to the pod.

## Configuration

All settings are in [config.json](./config.json):

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `namespace` | Yes | — | Your Kubernetes namespace |
| `pvc` | Yes | — | Your Persistent Volume Claim name |
| `public_ssh_key_path` | Yes | — | Path to your SSH public key |
| `image` | No | `ossci-dev:main` | Docker image for the session (must be Ubuntu/Debian-based) |
| `dev_user` | No | `root` | Username for SSH login |
| `dev_uid` | No | `0` | UID for the dev user |
| `dev_gid` | No | `0` | GID for the dev user |
| `home_dir` | No | `/home/ossci` | PVC mount path (persistent home directory) |
| `gpu_limit` | No | `1` | Number of AMD GPUs to allocate |
| `local_ssh_port` | No | `2222` | Local port for SSH forwarding |
| `local_web_port` | No | `8000` | Local port for web mode forwarding |

### Using a Custom Image

You can use any Ubuntu/Debian-based Docker image by setting the `image` field in `config.json`:

```json
{
  "namespace": "my-namespace",
  "pvc": "my-pvc",
  "public_ssh_key_path": "/home/user/.ssh/id_rsa.pub",
  "image": "ubuntu:24.04"
}
```

The SSH setup (installing `openssh-server`, creating the user, configuring keys) is handled automatically at pod startup regardless of the image. The image must support `apt-get`.

## VSCode Setup

You can launch a VSCode interactive environment inside your assigned Kubernetes namespace with your existing Persistent Volume Claim (PVC).
The environment supports two modes — browser-based (web) and SSH-based (ssh).

### SSH Mode

Runs a VSCode environment accessible via the VS Code Remote SSH extension.
The script forwards the pod's SSH port (22) to your local machine (default: 2222, configurable via `local_ssh_port` in config.json).

Add the following entry to your local `~/.ssh/config`:

```bash
Host ossci
  HostName 127.0.0.1
  User root
  Port 2222
  IdentityFile ~/.ssh/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

If you changed `dev_user` in config.json, update the `User` field above to match.

For multiple concurrent sessions using different `local_ssh_port` values, add a separate entry for each:

```bash
Host ossci-pytorch
  HostName 127.0.0.1
  User root
  Port 2222
  IdentityFile ~/.ssh/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host ossci-ubuntu
  HostName 127.0.0.1
  User root
  Port 2223
  IdentityFile ~/.ssh/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

You can connect either via the VS Code Remote SSH extension:

Remote-SSH: Connect to Host...
→ Select the host name from your `~/.ssh/config` (e.g., `ossci`, `ossci-pytorch`)


or directly from your terminal:

```bash
ssh ossci          # or whatever Host name you configured
```

If you are planning to use a remote host to start this interactive VSCode session, please ssh tunnel so that the ssh session that gets started is available on your local machine:

```bash
ssh -L <local_ssh_port>:localhost:<local_ssh_port> user@hostname
```

### Web Mode

Runs a browser-accessible VSCode server inside a pod.
Once ready, the script automatically forwards port 9000 from the pod to your local machine (default: 8000, configurable via `local_web_port` in config.json).

Access it in your browser at:

http://localhost:\<local_web_port\>

If you are planning to use a remote host to start this interactive VSCode session, please ssh tunnel so that the ssh session that gets started is available on your local machine:

```bash
ssh -L <local_web_port>:localhost:<local_web_port> user@hostname
```

### Usage

```bash
git clone git@github.com:nod-ai/ossci-fleet.git
cd ossci-fleet/example-templates/interactive/vscode
./run-vscode-interactive.sh
```

By default, the script starts in SSH mode. To use web mode instead:

```bash
./run-vscode-interactive.sh web
```

You can run multiple concurrent sessions by creating separate config files. The main fields to change between configs are `image` and `local_ssh_port` (each session needs a unique local port):

```json
// config-pytorch.json
{
  "namespace": "my-namespace",
  "pvc": "my-pvc",
  "public_ssh_key_path": "~/.ssh/id_rsa.pub",
  "image": "rocm/pytorch:latest",
  "local_ssh_port": "2222"
}

// config-ubuntu.json
{
  "namespace": "my-namespace",
  "pvc": "my-pvc",
  "public_ssh_key_path": "~/.ssh/id_rsa.pub",
  "image": "ubuntu:24.04",
  "local_ssh_port": "2223"
}
```

```bash
./run-vscode-interactive.sh --config config-pytorch.json
./run-vscode-interactive.sh --config config-ubuntu.json
```

The script reads your configuration from [config.json](./config.json) (namespace, PVC, SSH key, image, local ports) and automatically deploys the appropriate pod in your namespace.

The Docker image, number of GPUs, and other settings are all configurable via config.json — no need to edit the YAML templates directly.

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
export PATH=$HOME/therock-tarball/install/bin:$PATH
export LD_LIBRARY_PATH=$HOME/therock-tarball/install/lib
```

If you would like to use TheRock python packages or build from source, please refer to [therock.md](../the-rock/therock.md)

### Persistent Storage

Your home directory (/home/ossci) inside the VSCode environment is mounted from your PVC, ensuring that all your code, configurations, and data persist across sessions.
Use this directory for all your development work.
