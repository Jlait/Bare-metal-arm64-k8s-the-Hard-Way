

# Connection
# password is debian
ssh debian@ip-address

# Provisioning
brew install ansible sshpass
./provision_vms.sh   # creates missing VMs, writes machines.txt and ansible/inventory.ini
cd ansible
ansible-playbook bootstrap.yml --ask-pass --ask-become-pass   # first run only
ssh -i ~/.ssh/k8s-hard-way debian@ip-address
  