echo ">>> INITIATE ENV VARIABLES"
export GUID=`hostname|awk -F. '{print $2}'`
echo "export GUID=$GUID" >> $HOME/.bashrc
export INTERNAL=internal
export EXTERNAL=example.opentlc.com
export CURRENT_PATH=`pwd`

echo -- GUID = $GUID --
echo -- Internal domain = $INTERNAL --
echo -- External domain = $EXTERNAL --
echo -- Current path = $CURRENT_PATH --
echo  ">>> PREPARING HOSTS FILES"
cat /root/ocpAdvDepl/config/templates/hosts_template_ans.yaml | sed -e "s:{GUID}:$GUID:g;s:{DOMAIN_INTERNAL}:$INTERNAL:g;s:{DOMAIN_EXTERNAL}:$EXTERNAL:g;" > hosts
echo  "<<< PREPARING HOSTS FILES DONE"

echo  ">>> COPY NEW HOSTS TO ANSIBLE HOSTS"
cp hosts /etc/ansible/hosts
echo  "<<< COPY DONE"
