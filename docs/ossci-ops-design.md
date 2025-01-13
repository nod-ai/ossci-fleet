# OSSCI Ops Automated Solution Design

## Overview

This document describes the design of an automated solution for maintaining a Kubernetes cluster to reduce manual intervention and proactively detect and resolve issues regarding node health before they impact developers.
The architecture consists of three automated phases: a health checker service, a reboot service, and a reimaging service.
Together, these services ensure cluster reliability and streamline the node recovery process.

## Problem Statement

Maintaining a Kubernetes cluster requires significant manual effort, particularly in diagnosing and resolving node issues.
Issues like GPU failure, network degradation, or node misconfiguration can lead to downtime or degraded performance.
As someone that has been handling the ops side of the OSSCI cluster lately, GPU failure and network degradation have been the biggest pain points and what the following design hopes to mitigate.

## Solution Goals

### Primary Goals:

* Proactively detect node issues.
* Automate repair processes for common node failures.
* Escalate unresolved issues with sufficient diagnostics for manual attention.

### Non-Goals:

* Implement complex debugging for unknown issues.
* Manage non-node-related Kubernetes cluster issues.

## Software Architecture

The architecture consists of three core Kubernetes services:

### <ins>1. Health Checker Service</ins>

**Purpose:**

Continuously monitor node health and detect issues related to GPU functionality and network speed.

**Functionality:**

* Run the following tests on each node only if it does not have any repair taints (`repair-reboot`, `repair-reimage`, `repair-manual`):
  * GPU Health:
    *  `rocm-smi`: Checks GPU utilization and temperature.
    * `rocminfo`: Validates ROCm setup and GPU presence.
  * Network Health:
    * `speedtest`: Measures network speed and connectivity.
* Mark nodes with a `NoSchedule` taint `repair-reboot` if any **GPU Health** test fails three times.
* Mark nodes with a `NoSchedule` taint `slow-network` if any **Network Health** test fails three times.
* Remove `slow-network` taint if exists and **Network Health** passes on the node.

**How:**

* Daemonset configured to run on all healthy nodes in the cluster.
* Uses kubernetes service account with sufficient RBAC.
* Python script that runs tests every 30 seconds and marks node with `repair-reboot` taint if gpu tests fail or `slow-network` taint if network tests fail.
* We don't run on any nodes with `repair-` taints because that means the repair is in process.
* We still want to run on any node with `slow-network` because we want to see if network speeds have recovered.

**Output:**

* Nodes with failed GPU Health tests are `NoSchedule` tainted with `repair-reboot`.
* Nodes with failed Network Health tests are `NoSchedule` tainted with `slow-network`.
* Nodes with recovered network speeds will have `slow-network` taint removed.

### <ins>2. Reboot Service</ins>

**Purpose:**

Automatically reboot nodes with the `repair-reboot` taint and verify their recovery.

**Functionality:**

* Scan for nodes with the `repair-reboot` taint.
* Reboot the node and wait 5 minutes for it to stabilize.
* Rerun the health check tests (GPU).
* Update the node’s taints based on the results:
  * `Pass`: Remove `repair-reboot` taint -> node is healthy.
  * `Fail`: Remove `repair-reboot` taint -> apply `repair-reimage` `NoSchedule` taint.

**How:**

* Daemonset configured to run on all nodes in the cluster.
* Uses kubernetes service account with sufficient RBAC.
* Python script that checks for `repair-reboot`taint. If detected, performs a reboot and re-runs tests with pass/fail behavior as outlined above.

**Output:**

* Healthy nodes are cleared of taints.
* Nodes that fail upon reboot are tainted with `NoSchedule` `repair-reimage`.

### <ins>3. Reimaging Service</ins>

**Purpose:**

Reimage nodes with severe issues to ensure they are restored to a clean state.

**Functionality:**

* Scan for nodes with the repair-reimage taint.
* Run a reimaging script to reinstall ROCm.
* Reboot the node and wait 5 minutes.
* Re-run the GPU health checks to verify recovery.
* Update the node’s taints based on the results:
  * `Pass`: Remove `repair-reimage` taint -> node is healthy.
  * `Fail`: Remove `repair-reimage` taint -> apply `repair-manual` taint -> notify infrastructure team through outlook email with details
    * Node details (name, IP, labels).
    * Health check logs.
    * Automated repair attempts and outcomes.

**How:**

* Daemonset configured to run on all nodes in the cluster.
* Uses kubernetes service account with sufficient RBAC.
* Python script that checks for `repair-reimage`taint. If detected, performs a reimage, reboots, and re-runs tests with pass/fail behavior as outlined above.
* For now, reimaging based on https://rocm.docs.amd.com/projects/install-on-linux/en/latest/install/quick-start.html, but will see if there is something better we can leverage and will probably vary based on cluster

**Output:**

* Nodes are restored through reimage or escalated for manual intervention.
* Notifications are sent for unresolved issues.

## Key Components

* Programming Languages and Tools
  * `Languages`: Python (for scripts and orchestration), Bash (for health checks), Yaml (kubernetes service integration)
  * `Tools`: Kubernetes, kubelet, ROCm utilities (rocm-smi, rocminfo), Speedtest CLI.
* Kubernetes Resources
  * `Health Checker`: DaemonSet to monitor all nodes.
  * `Reboot Service`: DaemonSet running a periodic scanner and reboot.
  * `Reimaging Service`: DaemonSet running a periodic scanner integrated with the reimaging scripts.
* Notifications
  * Email sent out to SHARK infrastructure group

## Node Life Cycle Diagram

<img width="344" alt="{29056873-F3FD-4CF1-8A6F-F1CB443A51EA}" src="https://gist.github.com/user-attachments/assets/f2f74250-12d3-4d7f-b661-0e9fae7b2888" />

## Challenges and Mitigations

* One Node Recovery Period interfering with Other Nodes
  * Mitigation: DaemonSet on every node instead of Deployment in charge of all nodes
* Node Downtime During Recovery
  * Mitigation: Use taints to prevent scheduling on unhealthy nodes from the moment they fail a test.
* Reimaging Complexity
  * Mitigation: Standardize reimaging scripts and ensure they are thoroughly tested.
* False Positives in Health Checks:
  * Mitigation: Perform multiple retries for failed checks before marking a node unhealthy.

## Future Plans

* Integrate with ossci grafana to collect stats on per node health as well as an overview of overall cluster health and problematic nodes.
* Build test suite as we identify new pain points.
* Add more recovery methods as we learn more about existing tooling at AMD.

## Conclusion

This design provides a robust, automated solution for maintaining Kubernetes cluster node health, significantly reducing manual intervention, and ensuring a proactive approach to issue resolution.
By leveraging Kubernetes taints, labels, and custom services, this architecture can maintain high reliability and operational efficiency.
