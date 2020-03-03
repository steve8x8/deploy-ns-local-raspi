#!/bin/bash

## from https://raw.githubusercontent.com/steve8x8/deploy-ns-local-raspi/arm64-ubuntu-bionic/ns-local-install.sh

## TODO: set /etc/domainname

## Note: whole script to be run with user privileges

# check whether this is the right arch
CPU_MODEL=$(uname -m)
if [ "$CPU_MODEL" = "aarch64" ]
then
  echo "ARM64 architecture (\"aarch64\") confirmed"
else
  echo "Wrong platform. Found \"${CPU_MODEL}\", need \"aarch64\". Exit."
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
    echo "openaps: Nightscout will use the OpenAPS files"
    echo "mongodb: Nightscout will use a MongoDB"
    while true; do
	read -p "What storage do you want to use? Choose [mongodb] / openaps " storage
	case $storage in
		"") STORAGE="mongo" ; break;;
		mongodb) STORAGE="mongo"; break;;
		openaps) STORAGE="openaps"; break;;
		* ) echo "Please answer mongo or openaps. ";;
	esac
    done

    read -p " " -r
	=$REPLY
	
    while true; do
	read -p "Do you wish to install OpenAPS basic oref0? [Y]/n" yn
	case $yn in
		[Yy]* ) break;;
		[Nn]* ) break;;
	esac
    done
    INSTALL_OREF0=$yn

fi

# get the right node
# Ubuntu Bionic: 8.10
sudo apt-get install -y nodejs

# install dependencies 
# get git, mongodb 2.x from apt for now,and npm
# optional extra packages to easily debug stuff or to do better maintenance
EXTRAS="etckeeper tcsh lsof"
sudo apt-get install --assume-yes git npm $EXTRAS

if [[ ${INSTALL_MONGO,,} =~ "yes" || ${INSTALL_MONGO,,} =~ "y"  ]]
then
    wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
    sudo apt-get update
    sudo apt-get install mongodb-org -y
    # enable mongo
    sudo systemctl enable mongodb.service
    # check mongo status
    sudo systemctl status mongodb.service
    # get log of mongo
    tail -n10  /var/log/mongodb/mongodb.log
    grep 27017 /var/log/mongodb/mongodb.log
    echo "log should contain: [initandlisten] waiting for connections on port 27017"
fi

sudo npm cache clean -f
#sudo npm install npm -g
#sudo npm install n -g
#sudo n lts

# go home
mkdir -p ~/ns
cd ~/ns

# get start script
case $UNITS in
   mmol) curl -o start_nightscout.sh https://raw.githubusercontent.com/steve8x8/deploy-ns-local-raspi/arm64-ubuntu-bionic/start_nightscout.sh;;
   mg)   curl -o start_nightscout.sh https://raw.githubusercontent.com/steve8x8/deploy-ns-local-raspi/arm64-ubuntu-bionic/start_nightscout-mg.sh;;
esac
chmod +rx start_nightscout.sh

git clone https://github.com/nightscout/cgm-remote-monitor.git
# switching to cgm-remote-monitor directory
pushd cgm-remote-monitor/
# switch to dev (latest development version)
git checkout dev
# setup ns
./setup.sh
popd

# make autoboot
curl -o nightscout https://raw.githubusercontent.com/steve8x8/deploy-ns-local-raspi/arm64-ubuntu-bionic/nightscout
sudo mv nightscout /etc/init.d/nightscout
sudo chmod +x /etc/init.d/nightscout
sudo /etc/init.d/nightscout start
sudo /etc/init.d/nightscout status
sudo insserv -d nightscout

echo "deploy nightscout on raspi done :)"
echo "Don't forget to edit: /home/ubuntu/start_nightscout.sh"
echo "Nightscout logging can be found at: /var/log/nightscout.log"

case $OREF0 in
        [Yy]* ) break;;
        [Nn]* ) exit;;
esac

# Setup basis oref0 stuff
# https://openaps.readthedocs.io/en/master/docs/walkthrough/phase-2/oref0-setup.html
curl -s https://raw.githubusercontent.com/openaps/docs/master/scripts/quick-packages.sh | bash -
git clone -b dev git://github.com/openaps/oref0.git || (cd oref0 && git checkout dev && git pull)

echo "Please continue with step 2 of https://openaps.readthedocs.io/en/master/docs/walkthrough/phase-2/oref0-setup.html"
echo "cd && ~/ns/oref0/bin/oref0-setup.sh"
