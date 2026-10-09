#!/bin/bash

echo "Stopping VMs in UTM"

utmctl stop jumpbox
utmctl stop server
utmctl stop node-0
utmctl stop node-1


echo "Stopped VMs in UTM"