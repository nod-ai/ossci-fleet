# OSSCI Cluster User Guide

This guide describes how to setup your environment from anywhere on **AMD network or VPN** to access and utilize the AMD OSSCI Cluster.
All the MI300x nodes in this cluster are on an AMD service called Conductor. This allows them to be on the same corporate network and be able to communicate with each other even though geographically, they are located across the country. We have setup infrastructure so that these nodes are behind a kubernetes scheduler. This provides us with an easy way to allocate MI300 resources on demand instead of reserving and blocking off whole nodes. The goal is to improve our utilization of this scarce resource while making it available to a much larger crowd.

## Step 1: Kubernetes Setup
Run these two commands to pull in all the required dependencies and set the appropriate configurations to enable kubernetes on your system:

```
./setup_k8s.sh
export KUBECONFIG=anon.conf
```
The script assumes you are on a linux machine. If not, please refer to this guide to get setup: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/

## Step 2: Run Jobs on the Cluster

Now, you are ready to run jobs on the cluster.

### Option 1: Quick Test

If you want to just run a quick test, please use the `rocm-test.yaml` in this repo. 
All this job is configured to do is a quick test to see if GPUs are available.
Please change the job name [here](https://github.com/saienduri/ossci-cluster/blob/main/rocm-test.yaml#L4) to include your username. This is a shared namespace, so it helps avoid job contention/conflict with other jobs with the same name and helps us track better as well.
You can use this as a template and add whatever else you'd like to test [here](https://github.com/saienduri/ossci-cluster/blob/main/rocm-test.yaml#L17).

To run the job:
```
./run-k8s-job.sh rocm-test.yaml
```

This script will dispatch the job, display logs when finished, and delete the job as part of cleanup.

### Option 2: SDXL Inference

This job takes a bit more time (~10 minutes for the whole e2e compilation and inference flow), but is probably more in line with what you will be using the cluster for.
Again, please change the job name [here](https://github.com/saienduri/ossci-cluster/blob/main/rocm-test.yaml#L4) to include your username. This is a shared namespace, so it helps avoid any job contention/conflict with other jobs with the same name and helps us track better as well.
Please take a look [here](https://github.com/saienduri/ossci-cluster/blob/main/shark-test.yaml#L25) if you are interested in how you would setup environments and run different workloads.

To run the job:
```
./run-k8s-job.sh shark-test.yaml
```

This script will dispatch the job, display logs when finished, and delete the job as part of cleanup.
The last line of the log will be an url to the image you just generated :)

If you are more interested in a docker in docker type of workload, you would do something like this: https://gist.github.com/saienduri/67e8b1687bc08e9b9519e1febea23f80




