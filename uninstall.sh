#!/bin/bash

# cleanup previous install

sudo apt-get remove --purge nodejs mongodb\* -y
sudo -rf /var/*/mongodb
cd /etc/apt/sources.list.d
sudo rm node* mongo*
sudo apt-get remove --purge nginx -y
sudo apt-get remove --purge letsencrypt python-certbot-nginx openssl -y
sudo apt-get autoremove --purge -y
sudo rm -rf /etc/nginx
EDITOR=ed sudo crontab -e <<EOF
g/certbot/d
w
q
EOF

