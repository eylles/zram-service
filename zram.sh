#!/bin/sh

# PATH should only include /usr/* if it runs after the mountnfs.sh
# script.  Scripts running before mountnfs.sh should remove the /usr/*
# entries.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

# service name
ZRAM_SERVICE=zram
# service config file
ZRAM_CONFIG=zram-config
STREAMS=$(grep -c ^processor /proc/cpuinfo)

# defaults
ALGORITHM=lz4
RAM_PERCENTAGE=50
PRIORITY=100
MEM_LIMIT_PERCENTAGE=0

# Read configuration variable file if it is present
[ -r /etc/default/"$ZRAM_CONFIG" ] && . /etc/default/"$ZRAM_CONFIG"

echo () { printf %s\\n "$*" ; }

_start_() {
    if grep -q zram /proc/swaps; then
        echo "${ZRAM_SERVICE} already running, exiting"
        return 1
    else

        modprobe "$ALGORITHM"
        modprobe zram
        sleep 1

        MEMORY_KB=$(awk '/MemTotal/{print $2}' /proc/meminfo)
        MEMORY_TOTAL=$(( MEMORY_KB * 1024 ))
        ZRAM_DISK_SIZE=$(( MEMORY_TOTAL * RAM_PERCENTAGE / 100))

        zramctl -f

        zramctl /dev/zram0 -s $ZRAM_DISK_SIZE -t $STREAMS -a $ALGORITHM

        echo "waiting for zram device"
        until [ -b /dev/zram0 ]; do
            sleep 1
        done

        if [ ${MEM_LIMIT_PERCENTAGE} -gt 0 ]; then
            MEM_LIMIT_SIZE=$(( MEMORY_TOTAL * MEM_LIMIT_PERCENTAGE / 100));
            echo "${MEM_LIMIT_SIZE}" > /sys/block/zram0/mem_limit
        fi
        echo "zram device initiated"
        echo "activating device"
        mkswap -L SWAP_ZRAM_0 /dev/zram0 && echo "zram device labeled"
        sleep 1
        swapon -p $PRIORITY /dev/zram0 && echo "zram device activated"

        echo "${ZRAM_SERVICE} started"
    fi
}

_stop_() {
    if ! grep -c "/dev/zram" /proc/swaps >/dev/null; then
        echo "${ZRAM_SERVICE} NOT running, exiting"
        return 1
    else
        for n in $( seq $( grep -c "/dev/zram" /proc/swaps ) )
        do
            INDEX=$((n - 1))
            echo "deactivating /dev/zram$INDEX"
            swapoff /dev/zram$INDEX && echo "/dev/zram$INDEX deactivated"
            sleep 1
            zramctl -r /dev/zram$INDEX
        done

        wait
        sleep 1
        modprobe -r zram
        modprobe -r $ALGORITHM
        echo "${ZRAM_SERVICE} stopped"
    fi
}

case "$1" in
    "activate" ) _start_ ;;
    "deactivate" ) _restart_ ;;
esac
