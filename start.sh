#!/bin/bash

mycat() {
for file in "$@"
do
    cat 2>/dev/null `dirname $0`/"$file" \
    | grep -v '^#'
done
}

# start server, using the following files in the _dir of the script_
# - my.env extracted from backup (previous install)
# - my-host.env created with host specifics (this install)
# - my.env with overrides
if [ -n "$1" ]
then
    mod="-i"
    run="printenv"
else
    mod=""
    run="node server.js"
fi

# following the instructions in CONTRIBUTING.md:
mycat my-backup.env my-host.env my-overrides.env my-testing.env > my.env
npm run dev
#mycat my-backup.env my-host.env my-overrides.env > my.prod.env
#npm run prod
