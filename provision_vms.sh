#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$SCRIPT_DIR/debian-12-arm64-k8s-hard-way.utm"
UTM_DOCS="$HOME/Library/Containers/com.utmapp.UTM/Data/Documents"
PLISTBUDDY=/usr/libexec/PlistBuddy

if [[ ! -d "$TEMPLATE" ]]; then
  echo "Template not found: $TEMPLATE" >&2
  exit 1
fi

find_bundle() {
  local vm=$1 bundle
  for bundle in "$UTM_DOCS"/*.utm; do
    [[ -f "$bundle/config.plist" ]] || continue
    if [[ "$($PLISTBUDDY -c 'Print :Information:Name' "$bundle/config.plist" 2>/dev/null)" == "$vm" ]]; then
      echo "$bundle"
      return 0
    fi
  done
  return 1
}

mkdir -p "$UTM_DOCS"
open -a UTM

for vm in jumpbox server node-0 node-1; do
  if find_bundle "$vm" >/dev/null || utmctl status "$vm" >/dev/null 2>&1; then
    echo "$vm already exists, skipping"
    continue
  fi

  dest="$UTM_DOCS/$vm.utm"
  if [[ -e "$dest" ]]; then
    echo "$dest exists but is not registered in UTM, importing"
  else
    echo "Provisioning $vm"
    # -c uses APFS clonefile so the disk image isn't physically duplicated
    cp -Rc "$TEMPLATE" "$dest"

    mac=$(printf '52:54:00:%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
    $PLISTBUDDY -c "Set :Information:Name $vm" "$dest/config.plist"
    $PLISTBUDDY -c "Set :Information:UUID $(uuidgen)" "$dest/config.plist"
    $PLISTBUDDY -c "Set :Network:0:MacAddress $mac" "$dest/config.plist"
  fi

  open -a UTM "$dest"

  for _ in {1..30}; do
    utmctl status "$vm" >/dev/null 2>&1 && break
    sleep 1
  done

  if utmctl status "$vm" >/dev/null 2>&1; then
    echo "$vm registered"
  else
    echo "Failed to register $vm in UTM" >&2
    exit 1
  fi
done

echo "VMs provisioned"

lease_ip() {
  # macOS writes MACs to dhcpd_leases without leading zeros per octet (e.g. 52:54:0:8c:b:37)
  local mac
  mac=$(echo "$1" | tr 'A-F' 'a-f' | sed -E 's/(^|:)0([0-9a-f])/\1\2/g')
  awk -v mac="1,$mac" -F= '
    $1 ~ /ip_address/ { ip = $2 }
    $1 ~ /hw_address/ && $2 == mac { print ip; exit }
  ' /var/db/dhcpd_leases 2>/dev/null
}

wait_for_ip() {
  local vm=$1 ip bundle mac=""
  if [[ "$(utmctl status "$vm" 2>/dev/null)" != "started" ]]; then
    utmctl start "$vm" || true
  fi
  if bundle=$(find_bundle "$vm"); then
    mac=$($PLISTBUDDY -c 'Print :Network:0:MacAddress' "$bundle/config.plist")
  fi
  for _ in {1..60}; do
    if [[ -n "$mac" ]]; then
      ip=$(lease_ip "$mac")
    else
      # utmctl ip-address can block forever without a guest agent, so cap it
      ip=$(perl -e 'alarm 10; exec @ARGV' utmctl ip-address "$vm" 2>/dev/null | grep -E '^[0-9]+(\.[0-9]+){3}$' | head -n1 || true)
    fi
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for IP of $vm" >&2
  return 1
}

machines="$SCRIPT_DIR/machines.txt"
inventory="$SCRIPT_DIR/ansible/inventory.ini"

echo "Waiting for IPs"
jumpbox_ip=$(wait_for_ip jumpbox || true)
server_ip=$(wait_for_ip server)
node0_ip=$(wait_for_ip node-0)
node1_ip=$(wait_for_ip node-1)

cat > "$machines" <<EOF
$server_ip server.kubernetes.local server
$node0_ip node-0.kubernetes.local node-0 10.200.0.0/24
$node1_ip node-1.kubernetes.local node-1 10.200.1.0/24
EOF

{
  echo "[jumpbox]"
  [[ -n "$jumpbox_ip" ]] && echo "jumpbox ansible_host=$jumpbox_ip"
  echo
  echo "[server]"
  echo "server ansible_host=$server_ip"
  echo
  echo "[nodes]"
  echo "node-0 ansible_host=$node0_ip pod_subnet=10.200.0.0/24"
  echo "node-1 ansible_host=$node1_ip pod_subnet=10.200.1.0/24"
} > "$inventory"

if [[ ! -f "$HOME/.ssh/k8s-hard-way" ]]; then
  ssh-keygen -t ed25519 -N "" -C k8s-hard-way -f "$HOME/.ssh/k8s-hard-way"
fi

echo "--- $machines"
cat "$machines"
echo "--- $inventory"
cat "$inventory"
