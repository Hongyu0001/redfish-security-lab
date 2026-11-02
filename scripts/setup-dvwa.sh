#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "[1/6] apt update"
sudo apt-get update -y
echo "[2/6] install lamp"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 mariadb-server php libapache2-mod-php php-mysql php-gd php-curl php-xml php-mbstring unzip
echo "[3/6] deploy files"
rm -rf DVWA-master
unzip -oq dvwa-master.zip
sudo rm -rf /var/www/html/dvwa
sudo cp -r DVWA-master /var/www/html/dvwa
echo "[4/6] db"
sudo systemctl enable --now mariadb
sudo mysql -e "CREATE DATABASE IF NOT EXISTS dvwa DEFAULT CHARACTER SET utf8mb4;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'p@ssw0rd';"
sudo mysql -e "GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost'; FLUSH PRIVILEGES;"
echo "[5/6] config"
sudo cp /var/www/html/dvwa/config/config.inc.php.dist /var/www/html/dvwa/config/config.inc.php
sudo sed -i "s/db_user' ] = 'root'/db_user' ] = 'dvwa'/" /var/www/html/dvwa/config/config.inc.php
sudo sed -i "s/db_password' ] = ''/db_password' ] = 'p@ssw0rd'/" /var/www/html/dvwa/config/config.inc.php
for f in /etc/php/*/apache2/php.ini; do
  sudo sed -i "s/^allow_url_fopen = Off/allow_url_fopen = On/" "$f"
  sudo sed -i "s/^allow_url_include = Off/allow_url_include = On/" "$f"
done
echo "[6/6] restart"
sudo systemctl restart apache2
sudo chown -R www-data:www-data /var/www/html/dvwa
sudo chmod -R 755 /var/www/html/dvwa
echo "done. open http://localhost/dvwa/setup.php"
