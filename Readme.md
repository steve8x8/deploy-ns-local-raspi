__Brief:__

Use this script to setup a complete local running Nightscout instance on a RasPi 3B or better, running Ubuntu Bionic.
This script can either:
 * install a local MongoDB instance (recommended!) or
 * work without MongoDB and use static OpenAPS report files (recommended for tiny rigs)

__Tested with:__

 * Raspberry Pi 3B+ (1GB RAM, 2GB swapfile)
 * Raspberry Pi 3B  (1GB RAM, no install, using same SDcard instead)

__ToDo:__

 * reverse proxy, SSL certificate
 * more tests (RasPi 4, anyone?)

__Notes:__

 Some steps require a deeper knowledge of Linux and/or your "everyday OS". Those are marked with a (+).
 No further explanations will be given. Ask your favourite search engine, or a real person you can trust.

__Prerequisites:__

 X. Starting with version 4, the RasPi must be updated with the latest (Raspbian-provided) firmware, see
	https://jamesachambers.com/raspberry-pi-4-bootloader-firmware-updating-recovery-guide/

 0. Install Raspberry Pi SD card (minimum 4 GB) with Debian Ubuntu "Bionic", ready for RasPi 4B from
	https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/

    At the time of this writing, Version 28 (18.04.4) was provided. Check for updates at
	https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial/releases

    This comes as a server-only image; addition of desktop is possible, see James's instructions.
    You may require a bigger SD card, 8 or 16 GB.


 1. Configure your Raspberry Pi
    Let RasPi always boot up fully (`cloud-init` must have finished) before logging in.
    Initial username: `ubuntu` Password: `ubuntu`

    The initial keymap will be US! Do not use any special characters for the new password yet
    unless you're 110% sure you will be able to enter it once the keymap has been adjusted!
    Most alphabet characters (except qwzy) and numbers are safe.

   `$ sudo raspi-config`
```
    1 Change User Password (and remember the new setting) if not yet done
    2.N1 Hostname ==> set to "ns"
    2.N3 Predictable interface names ==> set to "no"
    3.B1, 3.B3 Boot options ==> Choose what you want
    3.B2 Wait for Network at Boot ==> Set to No
    4 Internationalisation Options => Change Locale, Timezone, Keyboard Layout, Wi-Fi country to your needs
    4.I3 Keyboard layout ==> match your keyboard
    5.P2 SSH ==> enable
    7 Advanced Options
    7.A1 Expand Filesystem   ==> Make use of the whole SD card (may be already done?)
```
    Select "Finish" to reboot

 2. Some more adjustments.

 2.1. Network:
     * Pick up your IP address if you don't know it yet: `ip a`
     * If you don't have DHCP, configure the network. (+)

 2.2. Virtual memory:
     * Check with "free", for the installation, you will need 1500 MB at least.
     * If necessary, add a swapfile. (+)
     * Memory usage will be lower once the software has been setup.

 3. Make sure your system is up to date:
   `$ sudo apt-get update -qq && sudo apt-get dist-upgrade -y`

 4. Optionally, tweak your Raspberry Pi.
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

 1. Open console on your RasPi, directly or via e.g., `ssh ubuntu@192.168.10.4` (you still remember the password you set before?).

    Create, and `cd` to, a working directory - `~/ns` will be used by the script.
    It is recommended to keep your local copy of this deployment code there as well:
    ```
    mkdir -p ~/ns
    cd ~/ns
    git clone -b arm64-ubuntu-bionic https://github.com/steve8x8/deploy-ns-local-raspi
    ```
    You may place there:
    - a `*.tar` file with a recent DB backup which may contain a `my.env` file
    - a `my-overrides.env` file to override the backup one and the automatically generated entries,
    e.g. setting new values for
    ```
    HOSTNAME=ns.your_local_domain
    CUSTOM_TITLE=mysitename_without_spaces
    API_SECRET=my_12_characters_or_more_password
    ```
    Do not touch PORT!
    - ...

     Then
    ```
    cd ~/ns/deploy-ns-local-raspi
    git checkout arm64-ubuntu-bionic
    ```

     Now go through the individual steps, preferably in this order:
    ```
    ./uninstall.sh         # only if there are remainders from previous attempts
    ./install.sh prepare
    ./install.sh mongodb
    ./install.sh nightscout
    ./install.sh restore
    ./install.sh setup
    ```
    (You will get a comprehensive list of options by running `./install.sh help`.)

    Be prepared to wait - the "mongodb" and "nightscout" steps are rather time-consuming.
     In particular the "nightscout" step will take *more than 30 minutes on a RasPi 3B+*.

    _FIXME: Add detailed description of the individual steps._

 2. After running all steps you will have a running nightscout local installation.
    Navigate to http://your.host.name:1337/ for local access, e.g. complete nightscout profile settings

 3. A reverse proxy (nginx) and HTTPS access (using a LetsEncrypt SSL Certificate) will be provided later,
    their setup may have to be run on another machine (your web server if it exists).

    How to provide external access is not subject of these instructions (+)

 4. Have fun :smiley:

__Troubleshooting:__

 * mongodb: check `cat /var/log/mongodb/mongod.log` should contain: `[listener] waiting for connections on port 27017`
 * nodejs manual start: `ubuntu@raspi:~/ns/cgm-remote-monitor $ ../start.sh` (must be in cgm-remote-monitor directory)
 * nodejs / nightscout log: check `cat /var/log/nightscout.log`

__Changelog:__

2020-03-07:

- split into separate install steps, more debugging

2020-03-06:

- convert to systemd, multiple input files, ...

2020-03-04:

- some tweaks, in-place substitutions, etc.

2020-03-03:

- initially adopted by steve8x8, for use with RasPi 3B and up, running 64-bit Ubuntu Bionic
- use Node from APT, Mongo from mongodb.org

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
