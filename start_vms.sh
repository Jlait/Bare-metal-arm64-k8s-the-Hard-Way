#!/bin/bash

echo "Starting VMs in UTM"

utmctl start jumpbox
utmctl start server
utmctl start node-0
utmctl start node-1

echo "VMs Started"