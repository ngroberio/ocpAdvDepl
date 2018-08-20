echo ">>> INITIATE ENV VARIABLES"
export GUID=`hostname|awk -F. '{print $2}'`
export INTERNAL=internal
export EXTERNAL=example.opentlc.com

echo -- GUID = $GUID --
echo -- Internal domain = $INTERNAL --
echo -- External domain = $EXTERNAL --
echo  ">>> PREPARING HOSTS FILES"
cat /root/ocpAdvDepl/config/templates/hosts_template_ans.yaml | sed -e "s:{GUID}:$GUID:g;s:{DOMAIN_INTERNAL}:$INTERNAL:g;s:{DOMAIN_EXTERNAL}:$EXTERNAL:g;s:{PATH}:$CURRENT_PATH:g;" > hosts
echo  "<<< PREPARING HOSTS FILES DONE"

echo  ">>> COPY NEW HOSTS TO ANSIBLE HOSTS"
cp hosts /etc/ansible/hosts
echo  "<<< COPY DONE"