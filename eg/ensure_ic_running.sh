#!/bin/bash

# start me in cron with @reboot

trap 'exit 1' INT

while :
do
    if ! /bin/pgrep -u MYUSER interchange; then
        sleep 1
        if ! /bin/pgrep -u MYUSER interchange; then
            /home/MYUSER/path/to/interchange/bin/restart
            #echo "Check things out ASAP." | mail -s "MYUSER Interchange found down and restarted" me@foo.com
        fi
    fi
    sleep 15
done
