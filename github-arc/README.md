# OSSCI Integration with Github Playbook

Here is an example [workflow](./test_gpu.yml) that can be setup on a repo to leverage GitHub ARC enabled kubernetes cluster resources.

## Architecture

OSSCI is composed of several MI300 clusters. Some of these clusters are hosted within AMD on an internal service called conductor and others are hosted in different public CSPs. This allows each cluster to be on the same network and be able to communicate with each other.

### Kubespray

We leverage [kubespray](https://github.com/kubernetes-sigs/kubespray) to set up the kubernetes cluster across these nodes on bare metal. Kubespray is an ansible based deployment tool that takes care of installing the essential components such as etcd, kube-apiserver, kube-scheduler, and kube-controller-manager. It also takes care of configuring the networking layer for the cluster. The main value in kubespray is that it allows for great flexibility at each level of the configuration.

In our setup, use containerd for our container runtime, Calico for our network plugin (compatible with GPU workloads), and IPVS (IP Virtual Server) for managing and balancing network traffic between services and pods which is better than the default iptables at scale.

### Managed Kubernetes

When working with CSPs, we leverage the CSP's managed kubernetes offering if well supported such as AKS on Azure. In the overall architecture, it serves the same purpose as kubespray on bare metal which we leverage in on-prem clusters.

### AMD GPU Device Plugin for Kubernetes

It is neccesary for us to deploy the [AMD GPU device plugin](https://github.com/ROCm/k8s-device-plugin) on our cluster. It enables GPU-based workloads in Kubernetes, allowing scheduling and management of containers with AMD GPU access.

The plugin advertises available GPUs on each node to Kubernetes. When we deploy the plugin, it spins up a DaemonSet that automatically runs on GPU-capable nodes, discovers all GPUs, and registers them with Kubernetes as requestable resources for the node. GPU nodes are automatically labeled, and the scheduler assigns GPU requests to appropriate nodes.

We can control the number of gpus for our github runners by using the `resources.limits/requests`:

```
resources:
    requests:
      amd.com/gpu: 1
    limits:
      amd.com/gpu: 1
```

### GitHub Actions Runner Controller and Scale Set

![image](https://github.com/user-attachments/assets/0e81a513-8fa3-45ed-91da-34f5dd33caa6)


This part of the architecture allows us to create the connection between GitHub Actions and our k8s cluster. It registers a scale set of runners that we configure under a certain GitHub runner label (`mi300-cluster` in this repo), which we then use in the workflow file to run on our GPU enabled cluster. There are two main components to this piece of the architecture: `GitHub Actions Runner Controller` and `Runner Scale Set`.

The runner controller is a Kubernetes controller that manages self-hosted GitHub Actions runners within the cluster. It's main job is to deploy and manage runners dynamically as Kubernetes pods based on incoming workload demand (GitHub events such as Pull Requests that target our cluster label).

The runner scale set utilizes the Horizontal Pod Autoscaler (HPA) to scale runners based on queue length or CPU/GPU/memory usage. When deploying the runner scale set, we can specify the resources (memory, # cpu cores, # gpus) that are required by each of our runners.

More detailed setup details can be found here: https://github.com/nod-ai/AKS-GitHubARC-Setup/blob/main/README.md

## Getting Started

This architecture leads to a few questions to consider for preparing our cluster for any GitHub Repository

### Authentication

To create the connection so that our cluster can communicate with a GitHub Repository and register a runner scale set, the setup requires a GitHub PAT or GitHub App.
More details along with permission scope requirements can be found here: https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/authenticating-to-the-github-api

### GitHub Runner Requirements

1. How much memory do we want to allocate per GitHub Runner?
2. How many GPUs does each individual runner require?
3. How many cpu cores should be allocated for each runner?
4. What should be the minimum and maximum size of the scale set?

To answer 4, it is important to consider how long jobs that run on this cluster take and the frequency of these jobs.
