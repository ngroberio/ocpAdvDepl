#!/bin/bash

while getopts g:i:e:p: option
do
case "${option}"
in
g) GUID=${OPTARG};;
i) INTERNAL=${OPTARG};;
e) EXTERNAL=${OPTARG};;
p) CURRENT_PATH=${OPTARG};;
esac
done


if [ -z $GUID ]; then GUID=`hostname|awk -F. '{print $2}'`; fi
if [ -z $INTERNAL ]; then INTERNAL=internal; fi
if [ -z $EXTERNAL ]; then EXTERNAL=example.opentlc.com; fi
if [ -z $CURRENT_PATH ]; then CURRENT_PATH=`pwd`; fi

echo -- GUID = $GUID --
echo -- Internal domain = $INTERNAL --
echo -- External domain = $EXTERNAL -- 
echo -- Current path = $CURRENT_PATH --


echo  "-- Preparing hosts file --"
cat ./config/templates/hosts.template | sed -e "s:{GUID}:$GUID:g;s:{DOMAIN_INTERNAL}:$INTERNAL:g;s:{DOMAIN_EXTERNAL}:$EXTERNAL:g;s:{PATH}:$CURRENT_PATH:g;" > hosts

echo -- Installing atomic packages --
yum -y install atomic-openshift-utils atomic-openshift-clients

echo -- Installing screen --
yum -y install screen


echo -- Checking Openshift Prerequisites --
if ansible-playbook -f 20 -i ./hosts /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml ; then
    echo -- Prerequisites successful. Installing Openshift --
    screen -S os-install -m bash -c "sudo ansible-playbook -f 20 -i $CURRENT_PATH/hosts /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml"
    
    echo -- Copying kube config --
    ansible masters[0] -b -m fetch -a "src=/root/.kube/config dest=/root/.kube/config flat=yes"
    
    echo -- Creating user groups --
    oc adm groups new alpha Amy Andrew
    oc adm groups new beta Brian Betty
    oc adm groups new common

    echo -- Creating nfs storage --
    ssh support1.2954.internal "bash -s" -- < ./config/infra/create_pvs.sh
    rm -rf pvs; mkdir pvs
    
    for i in {1..50} 
    do
      cat ./config/templates/pvs/pv${i}.template | sed -e "s:{GUID}:$GUID:g" > ./pvs/pv${i}; 
    done
    
    ansible nodes -i ./hosts -m shell -a "docker pull registry.access.redhat.com/openshift3/ose-recycler:latest"
    ansible nodes -i ./hosts -m shell -a "docker tag registry.access.redhat.com/openshift3/ose-recycler:latest registry.access.redhat.com/openshift3/ose-recycler:v3.9.30"

    cat ./pvs/* | oc create -f -

    echo -- Setting up CICD pipeline --
    oc login -u Amy -pr3dh4t1!
    oc new-project os-tasks-${GUID}-dev
    oc new-project os-tasks-${GUID}-test
    oc new-project os-tasks-${GUID}-prod

    echo -- Setting up Jenkins --
    oc new-app jenkins-persistent -p ENABLE_OAUTH=true -e JENKINS_PASSWORD=jenkins -n os-tasks-${GUID}-dev
    oc policy add-role-to-user edit system:serviceaccount:os-tasks-${GUID}-dev:jenkins -n os-tasks-${GUID}-test
    oc policy add-role-to-user edit system:serviceaccount:os-tasks-${GUID}-dev:jenkins -n os-tasks-${GUID}-prod

    oc policy add-role-to-group system:image-puller system:serviceaccounts:os-tasks-${GUID}-test -n os-tasks-${GUID}-dev
    oc policy add-role-to-group system:image-puller system:serviceaccounts:os-tasks-${GUID}-prod -n os-tasks-${GUID}-dev
    
    echo -- Setting up openshift-tasks app --
    oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n os-tasks-${GUID}-dev
    oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n os-tasks-${GUID}-test
    oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n os-tasks-${GUID}-prod

    cat ./config/templates/os-pipeline.yaml.template | sed -e "s:{GUID}:$GUID:g" > ./os-pipeline.yaml
    oc create -f ./os-pipeline.yaml -n os-tasks-${GUID}-dev
    
    echo -- Verify Jenkins is up --
    ./config/bin/podLivenessCheck.sh jenkins os-tasks-${GUID}-dev 15

    echo -- Running pipeline --
    oc start-build os-pipeline -n os-tasks-${GUID}-dev

    echo -- Set up autoscaler --
    oc autoscale dc/os-tasks --min 1 --max 10 --cpu-percent=80 -n os-tasks-${GUID}-prod


    echo -- Set up dedicated nodes --
    oc login -u system:admin
    oc label node node1.${GUID}.internal client=alpha
    oc label node node2.${GUID}.internal client=beta
    oc label node node3.${GUID}.internal client=common
#    TODO: Finish setting up dedicated nodes

 
else
    echo -- Prerequisites failed --
fi
