#!/usr/bin/env bash
set -euo pipefail
CONF=/var/ossec/etc/ossec.conf
sudo cp "$CONF" "$CONF.bak-20261102"
if ! sudo grep -q 'apache2/access.log' "$CONF"; then
sudo python3 - <<'PY'
p = '/var/ossec/etc/ossec.conf'
s = open(p).read()
if 'apache2/access.log' not in s:
    block = '  <localfile>\n    <log_format>apache</log_format>\n    <location>/var/log/apache2/access.log</location>\n  </localfile>\n</ossec_config>'
    s = s.replace('</ossec_config>', block, 1)
    open(p, 'w').write(s)
    print('localfile injected')
PY
fi
sudo cp /home/hongyu/redfish-lab/local_rules.xml /var/ossec/etc/rules/local_rules.xml
sudo chown root:wazuh /var/ossec/etc/rules/local_rules.xml
sudo chmod 640 /var/ossec/etc/rules/local_rules.xml
sudo /var/ossec/bin/wazuh-control restart
sleep 5
sudo systemctl is-active wazuh-manager
echo 'wazuh rules configured'
