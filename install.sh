#!/bin/bash

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
    ssh support1.2954.internal "bash -s" -- < ./config/infra/create_pvs.sh
    rm -rf pvs; mkdir pvs

    ./config/infra/pvs/create_pvs_5gigs.sh
    ./config/infra/pvs/create_pvs_10gigs.sh

    cat ./pvs/* | oc create -f -

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

    echo ">>> SET UP MULTITENANCY"
    ./config/infra/setup_multitenacy.sh
    echo "<<< SET UP MULTITENANCY DONE"

    echo ">>> START NODEJS_MONGO_APP SMOKE TEST"
    ./config/bin/nodejs_mongo_smoke_test.sh
    echo "<<< START NODEJS_MONGO_APP SMOKE TEST DONE"

    echo ">>> SETUP AMY CICD SIMPLE PIPELINE"
    oc login -u Amy -pr3dh4t1!
    oc new-project os-tasks-${GUID}-dev
    oc new-project os-tasks-${GUID}-test
    oc new-project os-tasks-${GUID}-stage
    oc new-project os-tasks-${GUID}-prod
    echo "<<< SETUP AMY CICD SIMPLE PIPELINE DONE"

    echo ">>> SETUP JENKINS"
    oc new-app jenkins-persistent -p ENABLE_OAUTH=true -e JENKINS_PASSWORD=jenkins -n os-tasks-${GUID}-dev
    echo ">>>>> ADD JENKINS USER PERMISSIONS TO SERVICEACCOUNT"
    oc policy add-role-to-user edit system:serviceaccount:os-tasks-${GUID}-dev:jenkins -n os-tasks-${GUID}-test
    oc policy add-role-to-user edit system:serviceaccount:os-tasks-${GUID}-dev:jenkins -n os-tasks-${GUID}-stage
    oc policy add-role-to-user edit system:serviceaccount:os-tasks-${GUID}-dev:jenkins -n os-tasks-${GUID}-prod
    oc policy add-role-to-group system:image-puller system:serviceaccounts:os-tasks-${GUID}-test -n os-tasks-${GUID}-dev
    oc policy add-role-to-group system:image-puller system:serviceaccounts:os-tasks-${GUID}-prod -n os-tasks-${GUID}-dev
    echo "<<< SETUP JENKINS DONE"

    echo ">>> SETUP OPENSHIFT TO RUN PIPELINE"
    oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n os-tasks-${GUID}-dev
    oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n os-tasks-${GUID}-test
    oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n os-tasks-${GUID}-stage
    oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n os-tasks-${GUID}-prod

    echo ">>> SETUP AUTOSCALER"
    oc autoscale dc/os-tasks --min 1 --max 2 --cpu-percent=80 -n os-tasks-${GUID}-dev
    oc autoscale dc/os-tasks --min 1 --max 2 --cpu-percent=80 -n os-tasks-${GUID}-test
    oc autoscale dc/os-tasks --min 1 --max 2 --cpu-percent=80 -n os-tasks-${GUID}-stage
    oc autoscale dc/os-tasks --min 1 --max 10 --cpu-percent=80 -n os-tasks-${GUID}-prod
    echo "<<< SETUP AUTOSCALER DONE"

    cat ./config/templates/os_pipeline_template.yaml | sed -e "s:{GUID}:$GUID:g" > ./os-pipeline.yaml
    oc create -f ./os-pipeline.yaml -n os-tasks-${GUID}-dev
    echo "<<< SETUP OPENSHIFT TO RUN PIPELINE DONE"

    echo ">>> JENKINS LIVENESS CHECK"
    ./config/bin/podLivenessCheck.sh jenkins os-tasks-${GUID}-dev 15

    echo ">>> RUN PIPELINE"
    oc start-build os-pipeline -n os-tasks-${GUID}-dev
    echo "<<< RUN PIPELINE DONE"
else
    echo ">>> PREREQUITES RUN FAILED"
fi
