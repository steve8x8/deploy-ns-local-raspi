#!/bin/bash

NSHOME=~/ns
NSPORT=1337
# FIXME: make this configurable
NSFQDN=${1:-ns.mydomain.selfhost.me}
NSUSER=nightscout
NSPASS=WeAreNotWaiting

## Note: whole script to be run with user privileges
if [ `id -u` -eq 0 ]
then
    echo "Attempted to run as root, refused."
    exit 1
fi

#@ FIXME: check whether sudo is available

## Some consistency checks.
# check whether this is the right arch
echo Checking CPU architecture...
CPU_MODEL=`uname -m`
if [ "${CPU_MODEL}" = "aarch64" ]
then
    echo "ARM64 architecture (\"aarch64\") confirmed."
else
    echo "Wrong platform. Found \"${CPU_MODEL}\", need \"aarch64\". Exit."
    exit 1
fi

echo Checking OS version...
OS_VERSION=`. /etc/os-release 2>/dev/null; echo ${VERSION_CODENAME}`
if [ "${OS_VERSION}" = "bionic" ]
then
    echo "Ubuntu Bionic (\"bionic\") confirmed."
else
    echo "Wrong OS. Found \"${OS_VERSION}\", need \"bionic\". Exit."
    exit 1
fi

echo Checking memory and swap...
TOTAL_MB=`free 2>/dev/null | awk '{s+=$2+0}END{printf("%.0f\n",s/1024)}'`
if [ ${TOTAL_MB} -ge 2048 ]
then
    echo "Memory looks sufficient (${TOTAL_MB} MiB found)."
else
    echo "Memory not sufficient (${TOTAL_MB} MiB found). 2048 MiB or more recommended. Add swap space."
    exit 1
fi

# create NS home if not yet there
mkdir -p ${NSHOME}

echo "Ready for installation. Some more checks:"

BACKUP=$(cd ${NSHOME}; ls 2>/dev/null -tr *.tar *.tar.gz | tail -n1)
if [ -n "${BACKUP}" ]
then
    echo "Will use ${NSHOME}/${BACKUP} to restore database and my.env"
fi
if [ -f ${NSHOME}/my.env ]
then
    echo "Will use ${NSHOME}/my.env to override some settings"
fi

read -p "Starting installation now ... take a seat and watch :) ... press ENTER before" x
sleep 5



# make me current
sudo apt-get update -qq && \
sudo apt-get upgrade -y

# install dependencies 
# optional extra packages to easily debug stuff or to do better maintenance
EXTRAS=""
#EXTRAS="$EXTRAS etckeeper tcsh lsof"
sudo apt-get install git ed ${EXTRAS} -y

wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc \
| sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse" \
| sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
sudo apt-get update -qq
sudo apt-get install mongodb-org -y
# enable mongo
sudo systemctl enable mongod.service
# restart just in case
sudo systemctl stop   mongod.service
sudo systemctl start  mongod.service
sleep 15
# check mongo status
sudo systemctl status mongod.service
# get log of mongo
sudo tail -n10  /var/log/mongodb/mongod.log
#sudo grep "port 27017" /var/log/mongodb/mongod.log
echo "log should contain a fresh record: [listener] waiting for connections on port 27017"

# replay database backup
if [ -n "${BACKUP}" ]
then
    TEMP=$(mktemp -d ${NSHOME}/untarXXXXXX)
    echo Using ${TEMP} to unpack tar
    pushd ${TEMP}
    tar xvf ${NSHOME}/${BACKUP}
    find . -type f \
    | while read f
    do
	mv $f ./
    done
#    cp -pi my.env ${NSHOME}/backup.env
    cp -p my.env ${NSHOME}/backup.env
    popd
#    mongorestore -u ${NSUSER} -p ${NSPASS} -d nightscout ${TEMP}/
    mongorestore -d nightscout ${TEMP}/
    rm -rf ${TEMP}
fi

# set some initial user privileges
mongo -shell << EOF
use nightscout
db.createUser({ user: "${NSUSER}", pwd: "${NSPASS}", roles: [{ role: 'readWrite', db:'nightscout'}] })
exit
EOF
# and limit access
grep -q '^security:' /etc/mongod.conf || \
sudo ed /etc/mongod.conf <<EOF
/^#security:/
a
security:
    authorization: 'enabled'
.
w
q
EOF

## MongoDB is done!

pwd
# get start script
cp -p start.sh my-*.env ${NSHOME}/
sed -i \
    -e "s~XXXFQDNXXX~${NSFQDN}~g" \
    -e "s~XXXPORTXXX~${NSPORT}~g" \
    -e "s~XXXUSERXXX~${NSUSER}~g" \
    -e "s~XXXPASSXXX~${NSPASS}~g" \
	${NSHOME}/my-*.env
chmod +rx ${NSHOME}/start.sh
# what it would set
echo "Running the Nightscout start script would set the following environment:"
${NSHOME}/start.sh debug | sort

# service script
cp -p nightscout.service ${NSHOME}/
sed -i -e "s~XXXNSHOMEXXX~${NSHOME}~g" ${NSHOME}/nightscout.service

cd ${NSHOME}
# get latest copy
[ -d cgm-remote-monitor ] || git clone https://github.com/nightscout/cgm-remote-monitor.git
# switching to cgm-remote-monitor directory
pushd cgm-remote-monitor/
# switch to dev (latest development version)
git checkout dev
git pull

# setup ns: this installs nodejs from nodesource!
./setup.sh
popd

# start at boot
sudo cp -p ${NSHOME}/nightscout.service /etc/systemd/system/
sudo systemctl daemon-reload
systemctl enable nightscout
systemctl start  nightscout
systemctl status nightscout


# disabled for now - this must be split off (to be run on a web server)
false && \
{
# nginx (johnmales)
sudo apt-get install nginx -y
sudo cp -p ${NSHOME}/nginx.avail   /etc/nginx/sites-available/default
# check
sudo nginx -t
# start at boot
sudo systemctl enable nginx
# restart
sudo service nginx restart
sudo service nginx status
# stop
sudo service nginx stop

# letsencrypt (johnmales)
sudo apt-get install letsencrypt python-certbot-nginx openssl -y
sudo letsencrypt certonly <<< "#{NSFQDN}"
sudo ls -lR /etc/letsencrypt/live
sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
# nginx config
cp -p nginx.* ${NSHOME}
sed -i -e "s~XXXFQDNXXX~${NSFQDN}~g" "s~XXXPORTXXX~${NSPORT}~g" ${NSHOME}/nginx.*
sudo cp -p ${NSHOME}/nginx.avail   /etc/nginx/sites-available/default
sudo cp -p ${NSHOME}/nginx.enabled /etc/nginx/sites-enabled/default
# check
sudo nginx -t
# start
sudo service nginx restart
sudo service nginx status
# certbot for le renewal, every Monday
EDITOR=ed sudo crontab -e << EOF
g/certbot/d
\$
a
30 2 * * 1 certbot renew >> /var/log/certbot.log
.
w
q
EOF
}

echo "deploy nightscout on raspi done :)"
echo "Nightscout logging can be found at: /var/log/nightscout.log"
