#!/usr/bin/env bash

mkdir -p /srv/nfs/user-vols/pv{1..200}

echo ">>> CREATE PV FOR USERS"

for pvnum in {1..50} ; do
  echo '/srv/nfs/user-vols/pv${pvnum} *(rw,root_squash)' >> /etc/exports.d/openshift-uservols.exports
  chown -R nfsnobody.nfsnobody /srv/nfs
  chmod -R 777 /srv/nfs
done
echo "<<< CREATE PV FOR USERS DONE"

echo ">>> RESTARTING NFS SERVER"
sudo systemctl restart nfs-server
echo "<<< RESTARTING NFS SERVER DONE"