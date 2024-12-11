# OSSCI Cluster User Guide

This guide describes how to setup your environment from anywhere on **AMD network or VPN** to access and utilize the AMD OSSCI Cluster.
All the MI300x nodes in this cluster. We have setup infrastructure so that these nodes are behind a kubernetes scheduler. This provides us with an easy way to allocate MI300 resources on demand instead of reserving and blocking off whole nodes. The goal is to improve our utilization of this scarce resource while making it available to a much larger crowd.

## Step 1: Kubernetes Setup
Run these two commands to pull in all the required dependencies and set the appropriate configurations to enable kubernetes on your system:

```
./setup_k8s.sh
export KUBECONFIG=anon.conf
```
The script assumes you are on a linux machine. If not, please refer to this guide to get setup: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/

## Step 2: Run Jobs on the Cluster

Now, you are ready to run jobs on the cluster. We've provided two sample
templates for running batch jobs for your convenience. We've also
provided a helper script `./run-k8s-job.sh` for easily running these job
templates.

If you have your own helper template you want to contribute, contributions
are welcome!

### Option 1: Base ROCm Job

If you want to just run a quick test, please use the `rocm-job-template.yaml` in this repo. 
All this job is configured to do is a run a hello-world to see if GPUs are available.
Please change the job name to include your username. This is a shared namespace, so it helps avoid job contention/conflict with other jobs with the same name and helps us track better as well.

To run the job:
```
./run-k8s-job.sh rocm-job-template.yaml
```

This script will dispatch the job, display logs when finished, and delete the job as part of cleanup.

### Option 2: SDXL Inference Pipeline

If you want to run a more advanced test, please use the `shark-job-template.yaml`.
This job takes a bit more time (~10 minutes for the whole e2e compilation and inference flow), but is probably more in line with what you will be using the cluster for.
Again, please change the job name to include your username. This is a shared namespace, so it helps avoid any job contention/conflict with other jobs with the same name and helps us track better as well.

To run the job:
```
./run-k8s-job.sh shark-job-template.yaml
```

This script will dispatch the job, display logs when finished, and delete the job as part of cleanup.
The last line of the log will be an url to the image you just generated :)

If you are more interested in a docker in docker type of workload, you would do something like this: https://gist.github.com/saienduri/67e8b1687bc08e9b9519e1febea23f80




