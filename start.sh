#!/bin/bash

mycat() {
for file in "$@"
do
    cat 2>/dev/null `dirname $0`/"$file" \
    | grep -v '^#' \
    | sed -e 's~  *~%20~g' -e 's~"~~g'
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
env ${mod} \
 $(mycat backup.env my-host.env my.env) \
  ${run}
