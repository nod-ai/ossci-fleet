# Using an NFS to allow a pod to access local Files

## Creating the Persistent Volume

First, find a persistent volume in the right region

| Host Name     | Region | Location           | IP |
|----------|--------|--------------|--------------------|
| banff-1e707-e02-2.mkm.dcgpu | CA-GTA | Markham Campus  | rmm-banff-1e707-e02.amd.com |
| smc300x-clt-r4c4-34.cs-clt.dcgpu | US-Southeast | Charlotte Cirrascale Colo | 10.235.86.34 |
| smc300x-clt-r4c6-26.cs-clt.dcgpu | US-Southeast | Charlotte Cirrascale Colo | 10.235.86.43 |
| smc300x-clt-r4c6-34.cs-clt.dcgpu | US-Southeast | Charlotte Cirrascale Colo | 10.235.86.44 |
| banff-1e707-f07-5.mkm.dcgpu | CA-GTA | Markham Campus | rmm-banff-1e707-f07.amd.com |
| banff-sc-cs47-05.dh170.dcgpu | US-BayArea | Santa Clara DH170 Lab | 10.216.110.62 |
| dell300x-ccs-aus-B17-19.cs-aus.dcgpu | US-Texas | Austin Cirrascale Colo | 10.235.28.121 |
| SMC-SC-DI09-03.dh144.dcgpu | US-BayArea | Santa Clara DH144 Lab | 10.216.113.229 |

you can look at avaliable persistent volumes by running `kubectl get pv`
 
## Creating a persistent volume claim

Next, create a persistent volume claim using the template in `sample-persistent-volume-claim.yaml`

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-nfs-pvc
  namespace: dev
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: "nfs"
```
make sure the namespace matches your namespace.

this can then be applied with `kubectl apply -f sample-persistent-volume-claim.yaml`

## Verifying your PVC is set up correctly

you can run `kubectl get pv` with this expected output
```
NAME        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS        CLAIM                 STORAGECLASS    VOLUMEATTRIBUTESCLASS   REASON   AGE
my-nfs-pv   1Gi        RWX            Retain           Bound         dev/my-nfs-pvc        nfs             <unset>                          34m
```

and `kubectl get pvc -n <namespace>`
```
NAME         STATUS        VOLUME      CAPACITY   ACCESS MODES   STORAGECLASS    VOLUMEATTRIBUTESCLASS   AGE
my-nfs-pvc   Bound         my-nfs-pv   1Gi        RWX            nfs             <unset>                 30m
```

To confirm that the status of each is `Bound` and the storage class is `nfs`

## Giving your job access to your PVC

you need to add a few fields you you job.yaml file to make sure it can access the PVC

the  volume mounts needs to give a path to your NFS directory

```
        volumeMounts:
          - name: test-volume
            mountPath: /mnt/test-storage
```

and volumes needs to give the claim name
```
      volumes:
        - name: test-volume
          persistentVolumeClaim:
            claimName: my-nfs-pvc
```

A modified hello world script that has access to a nfs directory would look like this
```
# This job template makes it easy to create a job that depends on ROCm
apiVersion: batch/v1
kind: Job
metadata:
  # Change this name with something specific to you (aka include your username)
  name: rocm-test-job

# This is the pod spec that starts a rocm container using the latest tensorflow
# image that prebundles ROCm. Feel free to change the args or further customize
# the command to curate for your use case.
spec:
  template:
    spec:
      # please comment the nodeSelector like below if your pod fails to schedule
      # nodeSelector:
      #   dev: "true"
      nodeSelector:
        dev: "true"
      containers:
      - name: rocm-test-container
        image: rocm/tensorflow:latest
        command: ["/bin/bash", "-c"]
        args:
        - |
          ls -la /mnt/test-storage
        # This can be modified is more than 1 gpu is needed.
        volumeMounts:
          - name: test-volume
            mountPath: /path/to/nfs/directory
        resources:
          limits:
            amd.com/gpu: 1
      volumes:
        - name: test-volume
          persistentVolumeClaim:
            claimName: my-nfs-pvc
      restartPolicy: Never
  backoffLimit: 0
```