#!/bin/bash
echo ">> Liveness Check for Pod ${1} from Project ${2}"
sleep $3
while : ; do
  echo ">> Check Pod ${1} is Ready..."
  oc get pod -n $2 | grep $1 | grep -v build | grep -v deploy |grep "1/1.*Running"
  [[ "$?" == "1" ]] || break
  echo "...no. Sleeping ${3} seconds."
  sleep $3
done
