#!/bin/bash

mycat() {
for file in "$@"
do
#    echo "$file" >&2
    cat 2>/dev/null "$file" \
    | grep -v '^#' \
    | sed -e 's~  *~%20~g' -e 's~"~~g'
done
#    echo "done" >&2
}

# start server, using
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
 $(mycat backup.env) \
 $(mycat my-host.env) \
 $(mycat my.env) \
  ${run}
# sh -c 'printenv; node server.js'
