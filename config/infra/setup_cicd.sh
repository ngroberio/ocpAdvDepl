export GUID=`hostname | cut -d"." -f2`

echo ">>> SETUP CICD PROJECTS"
#oc login -u amy -pr3dh4t1!
#oc login -u system:admin
oc new-project cicd
oc new-project cicd-dev
oc new-project cicd-test
oc new-project cicd-prod
echo "<<< SETUP CICD PROJECTS DONE"

echo ">>> SETUP JENKINS"
oc new-app jenkins-persistent -p ENABLE_OAUTH=true -e JENKINS_PASSWORD=jenkins -n cicd
#oc create -f ./config/templates/setup_jenkins.yaml -n cicd
#oc new-app --template=jenkins-persistent -n cicd
#oc new-app -f ./config/templates/setup_jenkins.yaml -e OPENSHIFT_ENABLE_OAUTH=true -e JENKINS_PASSWORD=jenkins -n cicd

echo ">>>>> ADD JENKINS USER PERMISSIONS TO SERVICEACCOUNT"
oc policy add-role-to-user edit system:serviceaccount:cicd:jenkins -n cicd
oc policy add-role-to-user edit system:serviceaccount:cicd:jenkins -n cicd-dev
oc policy add-role-to-user edit system:serviceaccount:cicd:jenkins -n cicd-test
oc policy add-role-to-user edit system:serviceaccount:cicd:jenkins -n cicd-prod

oc policy add-role-to-user edit system:serviceaccount:cicd-dev:jenkins -n cicd
oc policy add-role-to-user edit system:serviceaccount:cicd-dev:jenkins -n cicd-dev
oc policy add-role-to-user edit system:serviceaccount:cicd-dev:jenkins -n cicd-test
oc policy add-role-to-user edit system:serviceaccount:cicd-dev:jenkins -n cicd-prod

oc policy add-role-to-user edit system:serviceaccount:cicd-test:default -n cicd
oc policy add-role-to-user edit system:serviceaccount:cicd-test:default -n cicd-dev
oc policy add-role-to-user edit system:serviceaccount:cicd-test:default -n cicd-test
oc policy add-role-to-user edit system:serviceaccount:cicd-test:default -n cicd-prod

oc policy add-role-to-user edit system:serviceaccount:cicd-prod:default -n cicd
oc policy add-role-to-user edit system:serviceaccount:cicd-prod:default -n cicd-dev
oc policy add-role-to-user edit system:serviceaccount:cicd-prod:default -n cicd-test
oc policy add-role-to-user edit system:serviceaccount:cicd-prod:default -n cicd-prod

oc policy add-role-to-group system:image-puller system:serviceaccounts:cicd -n cicd
oc policy add-role-to-group system:image-puller system:serviceaccounts:cicd-dev -n cicd
oc policy add-role-to-group system:image-puller system:serviceaccounts:cicd-test -n cicd
oc policy add-role-to-group system:image-puller system:serviceaccounts:cicd-prod -n cicd

echo "<<< SETUP JENKINS DONE"

echo ">>> SETUP OPENSHIFT TO RUN PIPELINE"
oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n cicd-dev
oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n cicd-test
oc new-app --template=eap70-basic-s2i --param APPLICATION_NAME=os-tasks --param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git --param SOURCE_REPOSITORY_REF=master --param CONTEXT_DIR=/ -n cicd-prod

echo ">>> SETUP HA UTOSCALER"
oc autoscale dc/os-tasks --min 1 --max 10 --cpu-percent=90 -n cicd-prod
echo "<<< SETUP AUTOSCALER DONE"

cat ./config/templates/os_pipeline_template.yaml | sed -e "s:{GUID}:$GUID:g" > ./os-pipeline.yaml
oc create -f ./os-pipeline.yaml -n cicd
echo "<<< SETUP OPENSHIFT TO RUN PIPELINE DONE"

echo ">>> JENKINS LIVENESS CHECK"
./config/bin/podLivenessCheck.sh jenkins cicd 15

echo ">>> RUN PIPELINE"
oc start-build os-pipeline -n cicd
echo "<<< RUN PIPELINE DONE"
