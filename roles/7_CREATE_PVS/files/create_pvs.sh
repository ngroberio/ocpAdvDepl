#!/usr/bin/env bash
export GUID=`hostname | cut -d"." -f2`

mkdir -p /srv/nfs/user-vols/pv{1..50}

echo ">>> CREATE PV FOR USERS"

for pvnum in {1..50}; do echo "/srv/nfs/user-vols/pv${pvnum} *(rw,root_squash)" >> openshift-uservols.exports; done
sudo cp ./openshift-uservols.exports /etc/exports.d/
chown -R nfsnobody.nfsnobody /srv/nfs
chmod -R 777 /srv/nfs

echo "<<< CREATE PV FOR USERS DONE"

echo ">>> RESTARTING NFS SERVER"
sudo systemctl restart nfs-server
echo "<<< RESTARTING NFS SERVER DONE"
