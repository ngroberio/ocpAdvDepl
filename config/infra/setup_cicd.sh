export GUID=`hostname | cut -d"." -f2`

echo ">>> SETUP CICD PROJECTS"
#oc login -u amy -pr3dh4t1!
#oc login -u system:admin
oc new-project cicd-dev
oc new-project tasks-dev
oc new-project tasks-test
oc new-project tasks-prod
echo "<<< SETUP CICD PROJECTS DONE"

echo ">>> SETUP JENKINS"
oc new-app jenkins-persistent -p ENABLE_OAUTH=true -e JENKINS_PASSWORD=jenkins -n cicd-dev
#oc create -f ./config/templates/setup_jenkins.yaml -n cicd-dev
#oc new-app --template=jenkins-persistent -n cicd
#oc new-app -f ./config/templates/setup_jenkins.yaml -e OPENSHIFT_ENABLE_OAUTH=true -e JENKINS_PASSWORD=jenkins -n cicd

echo ">>>>> ADD JENKINS USER PERMISSIONS TO SERVICEACCOUNT"
oc policy add-role-to-user edit system:serviceaccount:jenkins -n cicd-dev
oc policy add-role-to-user edit system:serviceaccount:jenkins -n tasks-dev
oc policy add-role-to-user edit system:serviceaccount:jenkins -n tasks-test
oc policy add-role-to-user edit system:serviceaccount:jenkins -n tasks-prod

oc policy add-role-to-user edit system:serviceaccount:admin -n cicd-dev
oc policy add-role-to-user edit system:serviceaccount:admin -n tasks-dev
oc policy add-role-to-user edit system:serviceaccount:admin -n tasks-test
oc policy add-role-to-user edit system:serviceaccount:admin -n tasks-prod

oc policy add-role-to-group system:image-puller system:serviceaccounts:jenkins -n cicd-dev
oc policy add-role-to-group system:image-puller system:serviceaccounts:admin -n cicd-dev

echo "<<< SETUP JENKINS DONE"

echo ">>> SETUP OPENSHIFT TO RUN PIPELINE"
oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n cicd-dev
#oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n tasks-dev
#oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n tasks-test
#oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n tasks-prod

echo ">>> SETUP HA UTOSCALER"
oc autoscale dc/os-tasks --min 1 --max 10 --cpu-percent=90 -n tasks-prod
echo "<<< SETUP AUTOSCALER DONE"

cat ./config/templates/os_pipeline_template.yaml | sed -e "s:{GUID}:$GUID:g" > ./os-pipeline.yaml
oc create -f ./os-pipeline.yaml -n cicd-dev
echo "<<< SETUP OPENSHIFT TO RUN PIPELINE DONE"

echo ">>> JENKINS LIVENESS CHECK"
./config/bin/podLivenessCheck.sh jenkins cicd-dev 15

echo ">>> RUN PIPELINE"
oc start-build os-pipeline -n cicd-dev
echo "<<< RUN PIPELINE DONE"
