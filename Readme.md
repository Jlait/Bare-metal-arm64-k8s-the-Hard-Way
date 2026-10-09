This repo was made for personal studying purposes. It's using UTM, Ansible, bash and utmctl to create and modify the Debian VMs.

# Provisioning

```bash
brew install ansible sshpass # Install deps if missing (on mac)

./provision_vms.sh   # creates missing VMs, writes machines.txt and ansible/inventory.ini

cd ansible

ansible-playbook bootstrap.yml --ask-pass --ask-become-pass   # first run only
```

# Connect to vm
```bash

ssh -i ~/.ssh/k8s-hard-way debian@ip-address
```