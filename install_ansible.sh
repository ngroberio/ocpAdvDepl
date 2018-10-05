#!/bin/bash
echo '>>>>>>>>>> [ SET ANSIBLE LOG ] <<<<<<<<<<<<'
export ANSIBLE_LOG_PATH=/var/log/ansible.log

echo '>>>>>>>>>> [ INITIATE ENV VARIABLES - EXPORT GUID ] <<<<<<<<<<<<'
export GUID=`hostname | cut -d"." -f2`; echo "export GUID=$GUID" >> $HOME/.bashrc
echo 'EXPORTED GUID >>> '$GUID

echo '>>>>>>>>>> [ RUN INSTALL PLAYBOOK ] <<<<<<<<<<<<'
ansible-playbook -v -f 20 config/templates/ansible_deployment_homework.yaml --extra-vars GUID=$GUID
