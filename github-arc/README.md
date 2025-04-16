# OSSCI Integration with GitHub Playbook

This playbook describes how we integrate GitHub ARC with our OSSCI setup to support CI workloads across projects in a containerized and resource efficient manner.

### GitHub Actions Runner Controller and Scale Set

![image](https://github.com/user-attachments/assets/0e81a513-8fa3-45ed-91da-34f5dd33caa6)


This allows us to create the connection between GitHub Actions and our k8s cluster. It registers a scale set of runners that we configure under a certain GitHub runner label (`mi300-cluster` in this repo), which we then use in the workflow file to run on our GPU enabled cluster. There are two main components to this piece of the architecture: `GitHub Actions Runner Controller` and `Runner Scale Set`.

The runner controller is a Kubernetes controller that manages self-hosted GitHub Actions runners within the cluster. It's main job is to deploy and manage runners dynamically as Kubernetes pods based on incoming workload demand (GitHub events such as Pull Requests that target our cluster label).

The runner scale set utilizes the Horizontal Pod Autoscaler (HPA) to scale runners based on queue length or CPU/GPU/memory usage. When deploying the runner scale set, we can specify the resources (memory, # cpu cores, # gpus) that are required by each of our runners.

More detailed setup details can be found here: https://github.com/nod-ai/AKS-GitHubARC-Setup/blob/main/README.md

## Getting Started

The OSSCI team will help setup the controller and scale set, but there are a few requirements for a succesful ARC deployment in k8s.

### Authentication

To create the connection so that our cluster can communicate with a GitHub Repository and register a runner scale set, the setup requires a GitHub App.
More details along with permission scope requirements can be found here: https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/authenticating-to-the-github-api

Please create a secret in your assigned namespace, so this authentication method can be used in kubernetes:
```
kubectl create secret generic pre-defined-rocm-secret    --namespace=<your-namespace>   --from-literal=github_app_id=<github-app-id>    --from-literal=github_app_installation_id=<github-app-installation-id>    --from-file=github_app_private_key=<path-to-your-github-app-private-pem-key>
```

### GitHub Runner Requirements

1. How much memory do we want to allocate per GitHub Runner?
2. How many GPUs does each individual runner require?
3. How many cpu cores should be allocated for each runner?
4. What should be the minimum and maximum size of the scale set?
5. Do your workflows use docker to run within container environments?

To answer 4, it is important to consider how long jobs that run on this cluster take and the frequency of these jobs.

### Values File

Based on the requirements above, please provide a values file to the OSSCI team similar to these examples:

1. [github-arc-dind-values.yaml](values/github-arc-dind-values.yaml) (Required if workflows use docker to run within container environments)
2. [github-arc-base-values.yaml](values/github-arc-base-values.yaml)

### Runner Scale Set Label

Also, please provide a label that we can use for your scale set deployment. This is the label that we target for the runs-on field in github workflows as seen in [sample-workflow](test_gpu.yml)
