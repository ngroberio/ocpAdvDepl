#!/usr/bin/env bash

export GUID=`hostname|awk -F. '{print $2}'`
oc new-project smoke-test-nodejs
oc new-app nodejs-mongo-persistent
sleep 70
oc get pod
oc get route
curl -i --head http://nodejs-mongo-persistent-smoke-test.apps.${GUID}.example.opentlc.com
sleep 30
oc delete project smoke-test-nodejs
oc project default
