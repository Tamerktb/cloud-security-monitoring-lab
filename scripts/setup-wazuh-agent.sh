#!/bin/bash
# Installs and registers a Wazuh agent on a Linux target
set -e

WAZUH_MANAGER_IP="$1"
WAZUH_AGENT_NAME="$2"

if [ -z "$WAZUH_MANAGER_IP" ] || [ -z "$WAZUH_AGENT_NAME" ]; then
  echo "Usage: $0 <MANAGER_IP> <AGENT_NAME>"
  exit 1
fi

echo "=== Installing Wazuh agent ==="
curl -sO "https://packages.wazuh.com/5.x/apt/pool/main/w/wazuh-agent/wazuh-agent_5.0.0-1_amd64.deb"
dpkg -i wazuh-agent_5.0.0-1_amd64.deb

echo "=== Configuring agent ==="
sed -i "s/\(<address>\).*\(<\/address>\)/\1$WAZUH_MANAGER_IP\2/" /var/ossec/etc/ossec.conf
sed -i "s/\(<agent_name>\).*\(<\/agent_name>\)/\1$WAZUH_AGENT_NAME\2/" /var/ossec/etc/ossec.conf

echo "=== Starting agent ==="
systemctl enable wazuh-agent
systemctl start wazuh-agent

echo "=== Agent installed. Register on the manager manually or use auto-enrollment. ==="
