#!/bin/bash

echo "Starting VMs in UTM"

for vm in jumpbox server node-0 node-1; do
  if [[ "$(utmctl status "$vm" 2>/dev/null)" == "started" ]]; then
    echo "$vm already running, skipping"
  else
    utmctl start "$vm"
  fi
done

echo "VMs Started"