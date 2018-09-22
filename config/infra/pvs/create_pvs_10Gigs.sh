#!/usr/bin/env bash
set ff=unix

export GUID=`hostname|awk -F. '{print $2}'`
export volsize="10Gi"
for volume in pv{26..50} ; do
cat << EOF > /root/pvs/pv${volume}
{
  "apiVersion": "v1",
  "kind": "PersistentVolume",
  "metadata": {
    "name": "${volume}"
  },
  "spec": {
    "capacity": {
        "storage": "${volsize}"
    },
    "accessModes": [ "ReadWriteMany" ],
    "nfs": {
        "path": "/srv/nfs/user-vols/pv${volume}",
        "server": "support1.${GUID}.internal"
    },
    "persistentVolumeReclaimPolicy": "Retain"
  }
}
EOF
echo "Created def file for ${volume}";
done;
