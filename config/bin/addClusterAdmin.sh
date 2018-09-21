#!/bin/bash
htpasswd -b /etc/origin/master/htpasswd admin r3dh4t1!
oc adm policy add-cluster-role-to-user cluster-admin admin
