#!/usr/bin/env bash
set -euo pipefail
rm -f /var/www/html/dvwa/hackable/uploads/probe_*.php
wget -qO /tmp/wazuh.key https://packages.wazuh.com/key/GPG-KEY-WAZUH
sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/wazuh.gpg /tmp/wazuh.key
echo 'deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main' | sudo tee /etc/apt/sources.list.d/wazuh.list > /dev/null
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wazuh-manager
sudo systemctl enable --now wazuh-manager
sleep 3
sudo systemctl is-active wazuh-manager
echo 'wazuh-manager ready'
