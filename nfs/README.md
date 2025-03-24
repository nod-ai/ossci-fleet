# Using an NFS to allow a pod to access local Files

## Creating the Persistent Volume

If you don't already have a persistent volume, you can request one by filing a ticket here https://ontrack-internal.amd.com/projects/OSSCI/summary

Specify the Region and size you want the PV to be in the ticket, and you will be provided with the name of a PV you can use
 
## Creating a persistent volume claim

Next, create a persistent volume claim using the template in `sample-persistent-volume-claim.yaml`

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  # You will need to use this name when assigning a mount to this claim
  name: my-nfs-pvc
  namespace: dev
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      # Put the amount of space you want to claim here.
      # should be equal to or less than the space requested
      storage: 1Gi
  storageClassName: "nfs"
  volumeName: <persistent-volume-name> #OSSCI will give you this name
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
            mountPath: /path/to/nfs/directory
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
          - name: test-volume # This is only used internally within the script to link the volumeMount to a Volume
            mountPath: /path/to/nfs/directory # This is where the data in your PV can be found within the pod
        resources:
          limits:
            amd.com/gpu: 1
      volumes:
        - name: test-volume # Make sure this matches the name under volumeMount
          persistentVolumeClaim:
            claimName: my-nfs-pvc # put the claim name defined in the previous script here
      restartPolicy: Never
  backoffLimit: 0
```