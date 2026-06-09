#!/bin/bash
# Installs Wazuh server (all-in-one) on Ubuntu 24.04
set -e

WAZUH_VERSION="4.9.0"

echo "=== Updating system ==="
apt-get update && apt-get upgrade -y

echo "=== Installing dependencies ==="
apt-get install -y curl apt-transport-https lsb-release gnupg2

echo "=== Installing Wazuh ==="
curl -sO "https://packages.wazuh.com/${WAZUH_VERSION%.*}/wazuh-install.sh"
bash wazuh-install.sh -a

echo "=== Installation complete ==="
echo "Access Wazuh dashboard at https://$(hostname -I | awk '{print $1}'):443"
echo "Credentials: admin / $(sudo tar -O -xzf wazuh-install-files.tar.gz wazuh-install-files/wazuh-passwords.txt | grep -m1 password | awk '{print $2}')"
