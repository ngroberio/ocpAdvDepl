#!/bin/bash
echo '>>>>>>>>>> [ SET ANSIBLE LOG ] <<<<<<<<<<<<'
export ANSIBLE_LOG_PATH=/var/log/ansible.log

echo '>>>>>>>>>> [ INITIATE ENV VARIABLES - EXPORT GUID ] <<<<<<<<<<<<'
export GUID=`hostname | cut -d"." -f2`; echo "export GUID=$GUID" >> $HOME/.bashrc
echo 'EXPORTED GUID >>> '$GUID

echo '>>>>>>>>>> [ RUN INSTALL PLAYBOOK ] <<<<<<<<<<<<'
ansible-playbook -v -f 20 ansible_deployment_homework_v2.yaml --extra-vars GUID=$GUID
