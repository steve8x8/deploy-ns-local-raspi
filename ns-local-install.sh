#!/bin/bash

NSHOME=~/ns

## TODO: set /etc/domainname (why?)
## TODO: use my.key from zehn.be export

## Note: whole script to be run with user privileges

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

# make me current
sudo apt-get update && sudo apt-get upgrade -y

# parse command line options
for i in "$@"
do
case $i in
    --mongo=*)
	INSTALL_MONGO="${i#*=}"
	shift # past argument=value
	;;
    --units=*)
	UNITS="${i#*=}"
	shift # past argument=value
	;;
    --storage=*)
	STORAGE="${i#*=}"
	shift # past argument=value
	;;
    --oref0=*)
	INSTALL_OREF0="${i#*=}"
	shift # past argument=value
	;;
    *)
	# unknown option
	echo "Option ${i#*=} unknown"
	;;
esac
done

if ! [[ ${INSTALL_MONGO,,} =~ "yes" || ${INSTALL_MONGO,,} =~ "no"  ]]; then
    echo ""
    echo "Unsupported value for --mongo. Choose either 'yes' or 'no'. "
    echo
    INSTALL_MONGO="" # to force a Usage prompt
fi

if ! [[ ${UNITS,,} =~ "mmol" || ${UNITS,,} =~ "mg" ]]; then
    echo ""
    echo "Unsupported value for --units. Choose either 'mmol' or 'mg'"
    echo
    UNITS="" # to force a Usage prompt
fi

if ! [[ ${STORAGE,,} =~ "openaps" || ${STORAGE,,} =~ "mongo" ]]; then
    echo ""
    echo "Unsupported value for --storage. Choose either 'openaps' (Nightscout will use OpenAPS files) or 'mongo' (MongoDB backend store)"
    echo
    STORAGE="" # to force a Usage prompt
fi

if ! [[ ${INSTALL_OREF0,,} =~ "yes" || ${INSTALL_OREF0,,} =~ "no"  ]]; then
    echo ""
    echo "Unsupported value for --oref0. Choose either 'yes' or 'no'. "
    echo
    INSTALL_OREF0="" # to force a Usage prompt
fi

if [[ -z "$INSTALL_MONGO" || -z "$UNITS" || -z "$STORAGE" || -z "$INSTALL_OREF0" ]]; then
    echo "Usage: ns-local-install.sh [--mongo=[yes|no]] [--units=[mmol|mg]] [--storage=[openaps|mongo]] [--oref0=[yes|no]]"
    read -p "Start interactive setup? [Y]/n " -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        exit
    fi

    while true; do
	read -p "Do you want to install MongoDB? [Y]/n" -r
	case $REPLY in
		"") INSTALL_MONGO="yes" ; break;;
		[Yy]* ) INSTALL_MONGO="yes" ; break;;
		[Nn]* ) INSTALL_MONGO="no" ; break;;
		* ) echo "Please answer yes or no";;
	esac
    done

    while true; do
	read -p "Do you want to use mmol or mg [mmol]/mg]? " unit
	case $unit in
		"") UNITS="mmol" ; break;;
		mmol) UNITS="mmol"; break;;
		mg) UNITS="mg"; break;;
		* ) echo "Please answer mmol or mg.";;
	esac
    done

    echo "Nightscout has two options for storage:"
    echo "mongodb: Nightscout will use a MongoDB"
    echo "openaps: Nightscout will use the OpenAPS files"
    while true; do
	read -p "What storage do you want to use? Choose [mongodb] / openaps " storage
	case $storage in
		"") STORAGE="mongo" ; break;;
		mongodb) STORAGE="mongo"; break;;
		openaps) STORAGE="openaps"; break;;
		* ) echo "Please answer mongo or openaps. ";;
	esac
    done

    while true; do
	read -p "Do you wish to install OpenAPS basic oref0? [N]/y" -r
	case $REPLY in
		"") INSTALL_OREF0="no" ; break;;
		[Yy]* ) INSTALL_OREF0="yes" ; break;;
		[Nn]* ) INSTALL_OREF0="no" ; break;;
		* ) echo "Please answer yes or no";;
	esac
    done

fi

echo Starting installation with INSTALL_MONGO=${INSTALL_MONGO} UNITS=${UNITS} STORAGE=${STORAGE} INSTALL_OREF0=${INSTALL_OREF0}
sleep 5

# install dependencies 
# optional extra packages to easily debug stuff or to do better maintenance
EXTRAS="etckeeper tcsh lsof"
EXTRAS=""
sudo apt-get install --assume-yes git ${EXTRAS}

if [[ ${INSTALL_MONGO,,} =~ "yes" || ${INSTALL_MONGO,,} =~ "y"  ]]
then
    wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
    sudo apt-get update
    sudo apt-get install mongodb-org -y
    # enable mongo
    sudo systemctl enable mongod.service
    # check mongo status
    sudo systemctl status mongod.service
    # restart just in case
    sudo systemctl restart mongod.service
    # get log of mongo
    sudo tail -n10  /var/log/mongodb/mongod.log
    sudo grep 27017 /var/log/mongodb/mongod.log
    echo "log should contain a fresh record: [listener] waiting for connections on port 27017"
fi

# create NS home if not yet there
mkdir -p ${NSHOME}

# get start script
# FIXME: use my.key instead
#curl -o ${NSHOME}/start_nightscout.sh https://raw.githubusercontent.com/steve8x8/deploy-ns-local-raspi/arm64-ubuntu-bionic/start_nightscout.sh
cp -p start_nightscout.sh ${NSHOME}/
[ "$UNITS" = "mg" ] && sed -i -e 's~=mmol~=mg/dl~g' ${NSHOME}/start_nightscout.sh
chmod +rx ${NSHOME}/start_nightscout.sh
# init script
#curl -o ${NSHOME}/nightscout.init https://raw.githubusercontent.com/steve8x8/deploy-ns-local-raspi/arm64-ubuntu-bionic/nightscout.init
cp -p nightscout.init ${NSHOME}/
sed -i -e "s~XXXNSHOMEXXX~${NSHOME}~g" ${NSHOME}/nightscout.init

cd ${NSHOME}
# get latest copy
[ -d cgm-remote-monitor ] || git clone https://github.com/nightscout/cgm-remote-monitor.git
# switching to cgm-remote-monitor directory
pushd cgm-remote-monitor/
# switch to dev (latest development version)
git checkout dev
git pull

# we do not neet to get the right node
# Ubuntu Bionic comes with 8.10
# NS would like to install the latest 8.x from NodeSource
#sudo apt-get install -y nodejs
#sudo npm cache clean -f
#sudo npm install npm -g
#sudo npm install n -g
#sudo n lts

# setup ns: this installs nodejs from nodesource!
./setup.sh
popd

# start at boot
sudo cp -p ${NSHOME}/nightscout.init /etc/init.d/nightscout
sudo chmod +x /etc/init.d/nightscout
sudo /etc/init.d/nightscout start
sudo /etc/init.d/nightscout status
sudo insserv -d nightscout

echo "deploy nightscout on raspi done :)"
echo "Don't forget to edit: ${NSHOME}/start_nightscout.sh"
echo "Nightscout logging can be found at: /var/log/nightscout.log"

case $INSTALL_OREF0 in
        [Yy]* ) break;;
        [Nn]* ) exit;;
esac

# Setup basic oref0 stuff
# https://openaps.readthedocs.io/en/master/docs/walkthrough/phase-2/oref0-setup.html
curl -s https://raw.githubusercontent.com/openaps/docs/master/scripts/quick-packages.sh | bash -
#git clone -b dev git://github.com/openaps/oref0.git || (cd oref0 && git checkout dev && git pull)
[ -d oref0 ] || git clone -b dev https://github.com/openaps/oref0.git
pushd oref0
git checkout dev
git pull
popd

echo "Please continue with step 2 of https://openaps.readthedocs.io/en/master/docs/walkthrough/phase-2/oref0-setup.html"
echo "cd && ${NSHOME}/oref0/bin/oref0-setup.sh"
