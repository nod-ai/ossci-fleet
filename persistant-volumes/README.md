# Persistent Volumes

## Azure Persistent Volume claims

you can create a claim using space from azure

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azure-disk-pvc
  namespace: arc-runners  # Ensure it's in the arc-runners namespace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5000Gi  # Adjust size as needed
  storageClassName: "managed-csi"  # Azure Disk CSI driver
```

## local Persistent Volume Claims

If you want to use a local directory, first create a persistent Volume

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/data
```

Then make a persistant volume claim

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: arc-runners  # Ensure it's in the arc-runners namespace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: "local-storage"
```

## Apply Yamls

apply you claim with

`kubectl apply -f pvc.yaml `

## Making sure runners have access to claims

when initializing a runner, make sure this data is included in the yaml

```
        volumeMounts:
          - name: <volume-name> #this can be anything but it needs to be consistent with the code below
            mountPath: /mnt/path/
```
```
    volumes:
      - name: <volume-name
        persistentVolumeClaim:
          claimName: <claim-name
```