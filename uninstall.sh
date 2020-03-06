#!/bin/bash

# cleanup previous install

sudo apt-get remove --purge nodejs mongodb\* -y
sudo -rf /var/*/mongodb
cd /etc/apt/sources.list.d
sudo rm node* mongo*

