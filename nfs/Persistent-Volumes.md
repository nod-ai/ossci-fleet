# Creating a Persistant Volume

First, make sure your directory is set up as an NFS. After that you can use this template stored in `sample-persistent-volume.yaml` to create a persistent volume

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: <persistent-volume-name>
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: <server-ip>
    path: /path/to/nfs/directory
```

Afterwards apply it with `kubectl apply -f sample-persistent-volume.yaml`

Make sure to increase storage space for any job that is not a simple example

the conductor servers can be found here

| Name | Host Name     | Region | Location           | IP |
|-------------|----------|--------|--------------|--------------------|
|banff-1e707-e02-2| banff-1e707-e02-2.mkm.dcgpu | CA-GTA | Markham Campus  | rmm-banff-1e707-e02.amd.com |
|smc300x-clt-r4c4-34| smc300x-clt-r4c4-34.cs-clt.dcgpu | US-Southeast | Charlotte Cirrascale Colo | 10.235.86.34 |
|smc300x-clt-r4c6-26| smc300x-clt-r4c6-26.cs-clt.dcgpu | US-Southeast | Charlotte Cirrascale Colo | 10.235.86.43 |
|smc300x-clt-r4c6-34| smc300x-clt-r4c6-34.cs-clt.dcgpu | US-Southeast | Charlotte Cirrascale Colo | 10.235.86.44 |
|banff-1e707-f07-5| banff-1e707-f07-5.mkm.dcgpu | CA-GTA | Markham Campus | rmm-banff-1e707-f07.amd.com |
|banff-sc-cs47-05| banff-sc-cs47-05.dh170.dcgpu | US-BayArea | Santa Clara DH170 Lab | 10.216.110.62 |
|dell300x-ccs-aus-B17-19| dell300x-ccs-aus-B17-19.cs-aus.dcgpu | US-Texas | Austin Cirrascale Colo | 10.235.28.121 |
|SMC-SC-DI09-03| SMC-SC-DI09-03.dh144.dcgpu | US-BayArea | Santa Clara DH144 Lab | 10.216.113.229 |

## Naming convention

When creating a new PV, use the naming convention `<Name>-<size>-<Index Based on Name>`

For example, if we needed to create a 3TB PV in SMC-SC-DI09-03, we would call it `SMC-SC-DI09-03-3TB-00`.  If we needed a second PV on the same host with 1TB of space, we would call it `SMC-SC-DI09-03-1TB-01`