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
The script forwards the pod's SSH port (22) to your local machine (2222).

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
./run-vscode-interactive.sh [--config config.json] <web|ssh>
```

You can maintain multiple config files for different setups (e.g., different images and local ports for concurrent sessions):

```bash
./run-vscode-interactive.sh --config config-pytorch.json ssh
./run-vscode-interactive.sh --config config-ubuntu.json ssh
```

The script reads your configuration from [config.json](./config.json) (namespace, PVC, SSH key, image) and automatically deploys the appropriate pod in your namespace.

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
export PATH=$HOME/therock-tarball/install/bin:$PATH
export LD_LIBRARY_PATH=$HOME/therock-tarball/install/lib
```

If you would like to use TheRock python packages or build from source, please refer to [therock.md](../the-rock/therock.md)

### Persistent Storage

Your home directory (/home/ossci) inside the VSCode environment is mounted from your PVC, ensuring that all your code, configurations, and data persist across sessions.
Use this directory for all your development work.
