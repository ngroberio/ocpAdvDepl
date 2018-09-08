#!/bin/bash

echo ">>> INITIATE ENV VARIABLES"
export GUID=`hostname|awk -F. '{print $2}'`
echo "export GUID=$GUID" >> $HOME/.bashrc
export INTERNAL=internal
export EXTERNAL=example.opentlc.com
export CURRENT_PATH=`pwd`

echo -- GUID = $GUID --
echo -- Internal domain = $INTERNAL --
echo -- External domain = $EXTERNAL --
echo -- Current path = $CURRENT_PATH --

echo  ">>> PREPARING HOSTS FILES"
./config/bin/initiateHostsTemplate.sh
echo  "<<< PREPARING HOSTS FILES DONE"

echo ">>> INSTALL ATOMIC PACKAGES"
yum -y install atomic-openshift-utils atomic-openshift-clients
echo "<<< INSTALL ATOMIC PACKAGES DONE"

echo ">>> INSTALL SCREEN"
yum -y install screen
echo "<<< INSTALL SCREEN DONE"

echo ">>> CHECK OPENSHIFT PREREQUISITES"
if ansible-playbook -f 20 -i ./hosts /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml ; then
    echo "<<< CHECK OPENSHIFT PREREQUISITES SUCCESSFUL"

    echo ">>> INSTALL OPENSHIFT"
    screen -S os-install -m bash -c "sudo ansible-playbook -f 20 -i $CURRENT_PATH/hosts /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml"
    echo ">>> INSTALL OPENSHIFT DONE"

    echo ">>> COPY KUBE CONFIG"
    ansible masters[0] -b -m fetch -a "src=/root/.kube/config dest=/root/.kube/config flat=yes"
    echo "<<< COPY KUBE CONFIG DONE"

    echo ">>> CREATE USER GROUPS"
    oc adm groups new alpha Amy Andrew
    oc adm groups new beta Brian Betty
    oc adm groups new common
    oc adm policy add-cluster-role-to-user cluster-admin user1

    echo "<<< CREATE USER GROUPS DONE"

    echo ">>> CREATE NFS STORAGE"
    #ssh support1.${GUID}.internal "bash -s" -- < ./config/infra/pvs/create_pvs.sh
    ./config/infra/pvs/create_pvs.sh
    ./config/infra/pvs/create_pvs_5gigs.sh
    ./config/infra/pvs/create_pvs_10Gigs.sh

    cat /root/pvs/* | oc create -f -

    echo "<<< CREATE NFS STORAGE DONE"

    echo ">>> FIX NFS PV RECYCLING"

    echo "PULL OSE RECYCLER IMAGE"
    ansible nodes -i ./hosts -m shell -a "docker pull registry.access.redhat.com/openshift3/ose-recycler:latest"

    echo "TAG OS RECYCLER IMAGE"
    ansible nodes -i ./hosts -m shell -a "docker tag registry.access.redhat.com/openshift3/ose-recycler:latest registry.access.redhat.com/openshift3/ose-recycler:v3.9.30"

    echo "<<< FIX NFS PV RECYCLING DONE"

    echo ">>> SET UP DEDICATED NODES"
    oc login -u system:admin
    oc label node node1.${GUID}.internal client=alpha
    oc label node node2.${GUID}.internal client=beta
    oc label node node3.${GUID}.internal client=common
    echo "<<< SET UP DEDICATED NODES DONE"

    echo ">>> START NODEJS_MONGO_APP SMOKE TEST"
    ./config/bin/nodejs_mongo_smoke_test.sh
    echo "<<< START NODEJS_MONGO_APP SMOKE TEST DONE"

    echo ">>> SETUP HA UTOSCALER"
    oc autoscale dc/os-tasks --min 1 --max 10 --cpu-percent=80 -n os-tasks-${GUID}-prod
    echo "<<< SETUP AUTOSCALER DONE"

    echo ">>> SETUP AND RUN CICD SIMPLE PIPELINE"
    ./config/infra/setup_cicd.sh

    echo ">>> SET UP MULTITENANCY"
    oc login -u system:admin
    ./config/infra/setup_multitenacy.sh
    echo "<<< SET UP MULTITENANCY DONE"

else
    echo ">>> PREREQUITES RUN FAILED"
fi
