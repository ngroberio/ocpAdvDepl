echo ">>> SETUP AMY CICD SIMPLE PIPELINE"
oc login -u Amy -pr3dh4t1!
oc new-project os-tasks-${GUID}-dev
oc new-project os-tasks-${GUID}-test
oc new-project os-tasks-${GUID}-stage
oc new-project os-tasks-${GUID}-prod
echo "<<< SETUP AMY CICD SIMPLE PIPELINE DONE"

echo ">>> SETUP JENKINS"
#oc new-app jenkins-persistent -p ENABLE_OAUTH=true -e JENKINS_PASSWORD=jenkins -n os-tasks-${GUID}-dev
oc create -f ./config/templates/setup_jenkins.yaml -n os-tasks-${GUID}-dev

echo ">>>>> ADD JENKINS USER PERMISSIONS TO SERVICEACCOUNT"
oc policy add-role-to-user edit system:serviceaccount:os-tasks-${GUID}-dev:jenkins -n os-tasks-${GUID}-dev
oc policy add-role-to-user edit system:serviceaccount:os-tasks-${GUID}-dev:jenkins -n os-tasks-${GUID}-test
oc policy add-role-to-user edit system:serviceaccount:os-tasks-${GUID}-dev:jenkins -n os-tasks-${GUID}-stage
oc policy add-role-to-user edit system:serviceaccount:os-tasks-${GUID}-dev:jenkins -n os-tasks-${GUID}-prod
oc policy add-role-to-group system:image-puller system:serviceaccounts:os-tasks-${GUID}-test -n os-tasks-${GUID}-dev
oc policy add-role-to-group system:image-puller system:serviceaccounts:os-tasks-${GUID}-stage -n os-tasks-${GUID}-dev
oc policy add-role-to-group system:image-puller system:serviceaccounts:os-tasks-${GUID}-prod -n os-tasks-${GUID}-dev
echo "<<< SETUP JENKINS DONE"

echo ">>> SETUP OPENSHIFT TO RUN PIPELINE"
oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n os-tasks-${GUID}-dev
oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n os-tasks-${GUID}-test
oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n os-tasks-${GUID}-stage
oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n os-tasks-${GUID}-prod

echo ">>> SETUP AUTOSCALER"
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
