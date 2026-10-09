#!/bin/bash

for vm in jumpbox server node-0 node-1; do
  echo "$vm: $(utmctl ip-address "$vm" | head -n1)"
done