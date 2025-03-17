# OSSCI Cluster User Guide

This guide describes how to setup your environment from anywhere on the **AMD network or VPN** to access and utilize the AMD OSSCI Cluster.
All the nodes in this cluster are MI300x. We have setup infrastructure so that these nodes are behind a kubernetes scheduler. This provides us with an easy way to allocate MI300x resources on demand instead of reserving and blocking off whole nodes. The goal is to improve our utilization of this scarce resource while making it available to a much larger crowd.

## Step 1: Kubernetes Setup
Please download anon.conf into your directory from `Getting Started` section in http://u.amd.com/ossci-cluster if you are generally testing the ossci-fleet.
If you already have a `KUBECONFIG` file provided to you to access a certain cluster with certain roles, please use that to access.
Run these two commands to pull in all the required dependencies and set the appropriate configurations to enable kubernetes on your system:

Linux:
```
export KUBECONFIG = "/path/to/your/anon.conf"
./linux/setup_k8s.sh
```

Windows PowerShell (elevated permissions required, so run as admin):
```
$env:KUBECONFIG = "C:\path\to\your\anon.conf"
.\windows\setup_k8s.ps1
```

Refer to https://kubernetes.io/docs/tasks/tools/ if you would rather install kubectl manually.

## Step 2: Run Jobs on the Cluster

Now, you are ready to run jobs on the cluster. We've provided two sample
templates for running batch jobs for your convenience. We've also
provided a helper script `run-k8s-job` for easily running these job
templates.

If you have your own helper template you want to contribute, contributions
are welcome!

### Option 1: Base ROCm Job

If you want to just run a quick test, please use the `rocm-job-template.yaml` in this repo.
All this job is configured to do is a run a hello-world to see if GPUs are available.
Please change the job name to include your username. This is a shared namespace, so it helps avoid job contention/conflict with other jobs with the same name and helps us track better as well.
Please use your assigned namespace in the kubernetes cluster. If you are just using anon.conf, you can use the `dev` namespace.

To run the job on Linux:
```
./linux/run-k8s-job.sh ./example-templates/workloads/rocm-job-template.yaml <namespace>
```

To run the job on Windows PowerShell:
```
.\windows\run-k8s-job.ps1 .\example-templates\workloads\rocm-job-template.yaml <namespace>
```

This script will dispatch the job, display logs when finished, and delete the job as part of cleanup.

### Option 2: SDXL Inference Pipeline

If you want to run a more advanced test, please use the `shark-job-template.yaml`.
This job takes a bit more time (~10 minutes for the whole e2e compilation and inference flow), but is probably more in line with what you will be using the cluster for.
Again, please change the job name to include your username. This is a shared namespace, so it helps avoid any job contention/conflict with other jobs with the same name and helps us track better as well.
Please use your assigned namespace in the kubernetes cluster. If you are just using anon.conf, you can use the `dev` namespace.

To run the job on Linux:
```
./linux/run-k8s-job.sh ./example-templates/workloads/shark-job-template.yaml <namespace>
```

To run the job on Windows PowerShell:
```
.\windows\run-k8s-job.ps1 .\example-templates\workloads\shark-job-template.yaml <namespace>
```

This script will dispatch the job, display logs when finished, and delete the job as part of cleanup.
The last line of the log will be an url to the image you just generated :)

### Option 3: Interactive Sessions

If you are interested in an interactive session for easier development and iteration, we support the creation of a jupyter notebook and vscode server.
Please change the pod name in the template yml file to include your NTID. This is a shared namespace, so it helps avoid any job contention/conflict with other jobs with the same name and helps us track better as well.
Please use your assigned namespace in the kubernetes cluster.

#### Visual Studio Code


To start your vscode server session:
```
kubectl apply -f ./example-templates/interactive/vscode-session.yml -n <namespace>
kubectl port-forward -n <namespace> <pod-name> <port-number-local>:<port-number-pod>
```
The port forward command allows you to forward a port from your local machine to the port number used in the pod yml, so you can access the server locally.
Now, you can use vscode on your browser at `http://localhost:<port-number-local>`

#### Jupyter Notebook


To start your jupyter notebook session:
```
kubectl apply -f ./example-templates/interactive/jupyter-session.yml -n <namespace>
kubectl port-forward -n <namespace> <pod-name> <port-number-local>:<port-number-pod>
```
The port forward command allows you to forward a port from your local machine to the port number used in the pod yml, so you can access the server locally.
Now, you can use jupyter notebook on your browser at `http://localhost:<port-number-local>`


### Option 4: Multi Node Training Workload

If you want to run a jax multi node training job, please use the `example-templates/workloads/jax-training-template`.
Please change the job name and configmap name to include your NTID. This is a shared namespace, so it helps avoid any job contention/conflict with other jobs with the same name and helps us track better as well.
Please use your assigned namespace in the kubernetes cluster.

To run the job on Linux:
```
./linux/run-k8s-job.sh ./example-templates/workloads/jax-training-template.yaml <namespace>
```

To run the job on Windows PowerShell:
```
.\windows\run-k8s-job.ps1 .\example-templates\workloads\jax-training-template.yaml <namespace>
```

If you see that the `head-node-labeler` service account is not available in your namespace, please ask a cluster maintainer to apply `example-templates/permissions/training-service-account` so you have the service account with the neccesary permissions to run training jobs in your namespace.
This script will dispatch the training job, display logs when finished, and delete the job as part of cleanup.

### Option 5: Dind

If you are more interested in a docker in docker type of workload, you would do something like this: https://gist.github.com/saienduri/67e8b1687bc08e9b9519e1febea23f80

## Debugging and Basic Usage

- Please following [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/) if your job fails.
- [Get a shell to a running container for interactive development](https://kubernetes.io/docs/tasks/debug/debug-application/get-shell-running-container/)
