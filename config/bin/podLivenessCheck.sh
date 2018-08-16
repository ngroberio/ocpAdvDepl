#!/bin/bash
echo ">> Liveness Check for Pod ${1} from Project ${2}"
sleep $3
while : ; do
  echo ">>>>> CHECK IF POD ${1} IS READY..."
  oc get pod -n $2 | grep $1 | grep -v build | grep -v deploy |grep "1/1.*Running"
  [[ "$?" == "1" ]] || break
  echo "NOT YET :( - WAITING FOR MORE ${3} SECONDS TO RETRY."
  sleep $3
done
