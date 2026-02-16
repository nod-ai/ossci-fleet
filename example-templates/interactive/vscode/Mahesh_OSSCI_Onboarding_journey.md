## Onboarding notes

- There is already a Security group setup, iree-dev@amd.com . If you are not already in there ask Mahesh Ravishankar or Benoit Jacob

- You dont need to create a JIRA ticket. That has already been created for IREE developers https://amd-hub.atlassian.net/browse/ARQ-80

- Please make sure you are connected to AMD VPN.

## Cluster Login

Please follow the steps here : https://amd.atlassian.net/wiki/spaces/SHARK/pages/1137428503/How+To+Connect+to+Kubernetes+using+Single+Sign+On

If you encounter SSL certificate verification issues, follow the automated solution on this [Confluence page](https://confluence.amd.com/pages/viewpage.action?spaceKey=XPPG&title=How+to+Add+AMD+Trusted+Certificate+Authority+Certs+to+Linux+and+Java+trusts+databases#HowtoAddAMDTrustedCertificateAuthorityCertstoLinuxandJavatrustsdatabases-Pleaseusetheautomatedsolutions) to add AMD Trusted CA certificates to your system.

Skip to installing CI tools. Note that I only tested using WSL Ubuntu on Windows.

- Install kubectl
- Install krew
- Install kubelogin
- Install kubeswitch
- Save the kubeconfig shared with you to ~/.kube/configs/conductor-mi35x.conf

Be aware of some characters added to you command line while you copy-paste. For example when copying this command

```
kubectl krew install oidc-login
```

I got some weird characters copied which led to this error

```
plugin name "oidc-login\u200b" not allowed
```

Just type the command manually to avoid this.

## VSCode setup

Generally need to follow https://github.com/nod-ai/ossci-fleet/blob/main/example-templates/interactive/vscode/README.md , but these are specific steps

1. Clone the ossci-fleet repo : https://github.com/nod-ai/ossci-fleet.git

2. There might be some issues launching vscode from within WSL. So we want to be able to create the pod from WSL but connect through the vscode from Windows. These steps worked for me

    a. Copy you public ID from Windows filesystem into WSL, so `\Users\mravisha\.ssh\id_rsa.pub` from the Windows filesystem into WSL at `~/windows_id.pub`

    b. Update `~/ossci-fleet/example-templates/interactive/vscode/config.json` to

    ```
    {
      "namespace": "iree-dev",
      "pvc": "iree-dev-mravisha-pvc",
      "public_ssh_key_path": "/home/mahesh/windows_id.pub"
    }
    ```

    Note: Update "pvc" field value to iree-dev-[your ntid]-pvc

    c. Add this to `\Users\mravisha\.ssh\config`

    ```
    Host ossci
      HostName 127.0.0.1
      User ossci
      Port 2222
      IdentityFile \Users\mravisha\.ssh\id_rsa
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
    ```

    e. Update `~/ossci-fleet/example-templates/interactive/vscode/vscode-session-ssh.yml` to use [iree-dev.Dockerfile](https://github.com/nod-ai/ossci-gitops/blob/main/docker-images/iree-dev.Dockerfile) that is prebuilt for iree-dev. E.g.,

    ```
    image: ghcr.io/nod-ai/ossci-gitops/iree-dev:main
    ```

    f. Run `~/ossci-fleet/example-templates/interactive/vscode/run-vscode-interactive.sh ssh`
    This will create the connection to your pod. Keep this window open. Once you are done hitting Ctrl-C here will terminate your pod connection and clean it up.

    g. Open VSCode and just connect to the Remote `ossci` (like you would connect to anyother remote machine). You can also ssh to the machine using `ssh ossci`. Essentially `ossci` is now your remote machine to use.

    > **Note:** If you encounter SSH connection hang issues, a previous command may still be occupying the port. Kill the previous process and try again.

    h. Your home directory (/home/ossci) inside the VSCode environment is mounted from your PVC, ensuring that all your code, configurations, and data persist across sessions. Use this directory for all your development work. Please install TheRock here as well following [these instructions](https://github.com/nod-ai/ossci-fleet/tree/main/example-templates/interactive/vscode#install-rocm)

    i. Please refer to these [usage tips/instructions](https://github.com/nod-ai/ossci-fleet/tree/main/example-templates/interactive/vscode#usage) for any further details, especially for **requesting multiple GPUs per node**
