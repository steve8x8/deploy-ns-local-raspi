__Brief:__

Use this script to setup a complete local running Nightscout instance on a RasPi 3B or better, running Ubuntu Bionic.
This script can either:
 * install a local MongoDB instance (recommended!) or
 * work without MongoDB and use static OpenAPS report files (recommended for tiny rigs)

__Tested with:__

 * Raspberry Pi 3B+ (1GB RAM, 2GB swapfile)
 * Raspberry Pi 3B  (1GB RAM, no install, using same SDcard instead)

__ToDo:__

 * Use my.env if provided (e.g., from a ns.10be.de DB backup)
 * More tests (RasPi 4, anyone?)

__Prerequisites:__

-1. Starting with version 4, the RasPi must be updated with the latest (Raspbian-provided) firmware, see
	https://jamesachambers.com/raspberry-pi-4-bootloader-firmware-updating-recovery-guide/

 0. Install Raspberry Pi SD card (minimum 4 GB) with Debian Ubuntu "Bionic", ready for RasPi 4B from
	https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/

   At the time of this writing, Version 18.04.4 was provided.
   This comes as a server-only image; addition of desktop is possible, see James's instructions.
   You may require a bigger SD card, 8 or 16 GB.


 1. Configure your Raspberry Pi
   Let RasPi boot up fully (`cloud-init` must have finished) before logging in.
   Initial username: ubuntu Password: ubuntu

   `$ sudo raspi-config`
    ```
    1. Expand Filesystem   ==> Make use of the whole SD card
    2. Change User Password (and remember the new setting)
    3. Bootoptions ==> Choose what you want
    4. Wait for Network at Boot ==> Set to No
    5. Internationalisation Options => Change Locale, Timezone, Keyboard Layout, Wi-Fi country to your needs
    7. Advanced Options
	A2. Hostname ==> Set your hostname. This will be used for the URL of your Nightscout
	A4. SSH ==> Enable SSH for remote access
    ```
   then reboot
 
 2. If you don't have DHCP, configure the network.
    Pick up your IP address if you don't know it yet: `ip a`
 
 3. Make sure your system is up to date:
   `$ sudo apt-get update && sudo apt-get dist-upgrade -y`

 4. Tweak your Raspberry Pi.
    See for example: https://openaps.readthedocs.io/en/latest/docs/walkthrough/phase-0/rpi.html for information on setting up your Raspberry Pi:

 * Configure WiFi Settings
 * Wifi reliability tweaks [optional]
 * Watchdog [optional]
 * Disable HDMI to conserve power [optional]
 * Configure Bluetooth Low Energy tethering [optional]

__Caveat:__

 The install script queries the CPU architecture and the OS running, and determines
 whether there's sufficient virtual memory to run both mongodb and node.js.
 It will exit prematurely if requirements aren't met.

__Usage:__

(The following uses 192.168.10.4 as the IP address. You know yours, substitute it accordingly.)

 1. Open console on your raspi, e.g., `ssh ubuntu@192.168.10.4` (you still remember the password you set before?).

    Create, and `cd` to, a working directory - `~/ns` will be used by the script.
    ```
    mkdir -p ~/ns
    cd ~/ns
    ```
     Then
    ```
    git clone https://github.com/steve8x8/deploy-ns-local-raspi.git
    cd deploy-ns-local-raspi
    git checkout arm64-ubuntu-bionic
    ```
     and run ns-local-install script for an interactive install:
    ```
    bash ns-local-install.sh
    ```
	answer a few questions, then
	relax and drink some :coffee: - script runtime is *more than 30 minutes on a RasPi 3B+*.

	You can also use a non-interactive install:
    ```
    bash ns-local-install.sh [--mongo=[yes|no]] [--units=[mmol|mg]] [--storage=[mongodb|openaps]] [--oref0=[no|yes]]
    ```
	For example: 
    ```
    bash ns-local-install.sh --mongo=yes --units=mmol --storage=mongo --oref0=no
    ```
	(which is the default behaviour)

 2. after running the script you will have a running nightscout local installation. Now open editor with your config for nightscout:
    `nano ~/ns/start-nightscout.sh` (or `vi` or `mcedit` or ...)

    You need to configure at least the lines close to the top of the file:
    ```
    CUSTOM_TITLE=mysitename_without_spaces
    API_SECRET=my_12_characters_or_more_password
    ```
    Put your personal password (at least 12 characters long) and the name of your site (just for display) there!
 
 3. once finished, restart nightscout with: `sudo /etc/init.d/nightscout stop && sudo /etc/init.d/nightscout start` or reboot
 4. navigate to http://192.168.10.4:1337/ complete nightscout profile settings
 5. Have fun :smiley:

__Troubleshooting:__

 * nodejs manual start: `ubuntu@raspi:~/ns/cgm-remote-monitor $ ../start-nightscout.sh` (must be in cgm-remote-monitor directory)
 * nodejs / nightscout log: check `cat /var/log/nightscout.log`
 * mongodb: check `cat /var/log/mongodb/mongod.log` should contain: `[listener] waiting for connections on port 27017`

__Changelog:__

2020-03-04:

- some tweaks, in-place substitutions, etc.
- ToDo: reverse proxy, ssl certificate, systemd integration

2020-03-03:

- initially adopted by steve8x8, for use with RasPi 3B and up, running 64-bit Ubuntu Bionic
- use Node from APT, Mongo from mongodb.org
- ToDo: check whether n is required at all; use/convert my.env; do we need oref0?; interactive defaults

2016-11-13:

- upgrade nightscout to 0.9.1-dev-20161112, in order to support openaps-storage, see https://github.com/nightscout/cgm-remote-monitor/pull/2114

2016-10-14: 

- change to nightscout 0.9.0 stable (Grilled Cheese)
- add start_nightscout.sh instead of my.env

2016-09:
~~I forked the current dev-branch of nightscout/cgm-remote-monitor and changed the mongodb compatibility problems. Now it runs smoothly with mongodb 2.x on a raspi!
Maybe the pull request gets accepted soon. As soon as I´m notified, I will change the script again to use the current dev-branch again.~~
The patches for mongo2.x compatibility are now merged back into the official dev branch.

__With help from:__

- https://github.com/SandraK82/deploy-ns-local-raspi
- https://c-ville.gitbooks.io/test/content/
- http://yannickloriot.com/2016/04/install-mongodb-and-node-js-on-a-raspberry-pi/
- https://www.einplatinencomputer.com/raspberry-pi-node-js-installieren/
- contributions from PieterGit

__More stuff found at:__
- https://github.com/schmitzn/howto-nightscout-linux
- https://github.com/viderehh/deploy-nightscout-local-debain (sic!)
- https://gist.github.com/frauzufall/c69f4a76730e3eb24e7a582d636765df/
- https://gist.github.com/tamoyal/10441108/

__Wishlist/To Do:__
- separate username/password for Mongo
- Nginx to use for https / letsencrypt certificate
- Script to create wifi hotspot on the raspberry pi
- ...
