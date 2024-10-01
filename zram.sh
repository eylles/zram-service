#!/bin/sh

# PATH should only include /usr/* if it runs after the mountnfs.sh
# script.  Scripts running before mountnfs.sh should remove the /usr/*
# entries.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

# service name
ZRAM_SERVICE=zram
# service config file
ZRAM_CONFIG=/etc/default/zram-config

############
# defaults #
############

# algorithm: lz4
default_ALGORITHM=lz4
ALGORITHM=$default_ALGORITHM
# mem percentage: 50
default_RAM_PERCENTAGE=50
RAM_PERCENTAGE=$default_RAM_PERCENTAGE
ram_perc_min=5
ram_perc_max=400
# swapping priority: 100
default_PRIORITY=200
PRIORITY=$default_PRIORITY
priority_min=200
priority_max=32000
# mem limit percentage: 0
default_MEM_LIMIT_PERCENTAGE=0
MEM_LIMIT_PERCENTAGE=$default_MEM_LIMIT_PERCENTAGE
mem_limit_min=0
mem_limit_max=100

echo () { printf %s\\n "$*" ; }

# usage: is_int "number"
is_int() {
  printf %d "$1" >/dev/null 2>&1
}

# return type: int
# usage: min value minimum_value
min () {
  if [ "$1" -lt "$2" ]; then
    result="$2"
  else
    result="$1"
  fi
  printf '%d\n' "$result"
}

# return type: int
# usage: max value maximum_value
max () {
  if [ "$1" -gt "$2" ]; then
    result="$2"
  else
    result="$1"
  fi
  printf '%d\n' "$result"
}

# Usage: getval "KEY" file
# Return: string
# Description:
#   Read a KEY=VALUE file and retrieve the Value of the passed KEY
getval(){
  # Setting 'IFS' tells 'read' where to split the string.
  while IFS='=' read -r key val; do
    # Skip over lines containing comments.
    # (Lines starting with '#').
    [ "${key##\#*}" ] || continue

    # '$key' stores the key.
    # '$val' stores the value.
    if [ "$key" = "$1" ]; then
      printf '%s\n' "$val"
    fi
  done < "$2"
}

_start_() {
    if grep -q zram /proc/swaps; then
        echo "${ZRAM_SERVICE} already set up, exiting"
        return 1
    else
        # calculate streams
        STREAMS=$(grep -c ^processor /proc/cpuinfo)

        # Read get values from config if present
        if [ -r "$ZRAM_CONFIG" ]; then
            ALGORITHM=$(getval "ALGORITHM" "$ZRAM_CONFIG")
            RAM_PERCENTAGE=$(getval "RAM_PERCENTAGE" "$ZRAM_CONFIG")
            PRIORITY=$(getval "PRIORITY" "$ZRAM_CONFIG")
            MEM_LIMIT_PERCENTAGE=$(getval "MEM_LIMIT_PERCENTAGE" "$ZRAM_CONFIG")
        fi

        # make sure algo from config is valid
        case "$ALGORITHM" in
            lzo|lzo-rle|lz4|lz4hc|zstd|deflate|842)
                : # do nothing
                ;;
            *)
                echo "warning: invalid compression algorithm, using default."
                echo "algorithm: $default_ALGORITHM"
                # use default
                ALGORITHM=$default_ALGORITHM
                ;;
        esac

        # check algorithm loads
        if modprobe -n "$ALGORITHM" 2>/dev/null; then
            modprobe "$ALGORITHM"
        else
            modprobe "$default_ALGORITHM"
        fi
        modprobe zram
        sleep 1

        # check that the numeric values from config are int
        if ! is_int "$RAM_PERCENTAGE"; then
            RAM_PERCENTAGE=$default_RAM_PERCENTAGE
        fi

        if ! is_int "$PRIORITY"; then
           PRIORITY=$default_PRIORITY
        fi

        if ! is_int "$MEM_LIMIT_PERCENTAGE"; then
            MEM_LIMIT_PERCENTAGE=$default_MEM_LIMIT_PERCENTAGE
        fi

        # prevent out of range values
        RAM_PERCENTAGE=$(min "$RAM_PERCENTAGE" "$ram_perc_min")
        RAM_PERCENTAGE=$(max "$RAM_PERCENTAGE" "$ram_perc_max")

        PRIORITY=$(min "$PRIORITY" "$priority_min")
        PRIORITY=$(max "$PRIORITY" "$priority_max")

        MEM_LIMIT_PERCENTAGE=$(min "$MEM_LIMIT_PERCENTAGE" "$mem_limit_min")
        MEM_LIMIT_PERCENTAGE=$(max "$MEM_LIMIT_PERCENTAGE" "$mem_limit_max")

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

        # zram optimizations
        if [ "$ALGORITHM" = "zstd" ]; then
            # zstd needs page clusters 0, else it will have higher latency and
            # reduced IOPS.
            clust=0
        else
            clust=1
        fi
        # consecutive page reads in advance, higher values improve compression
        echo "$clust" > /proc/sys/vm/page-cluster
        # higher values encourage the kernel to move pages to swap
        echo "200"    > /proc/sys/vm/swappiness
        # reclaim dentry and inode caches just half as much as the default 100
        echo "50"     > /proc/sys/vm/vfs_cache_pressure
        echo "30"     > /proc/sys/vm/dirty_ratio
        echo "3"      > /proc/sys/vm/dirty_background_ratio
        # deactivate watermark boost
        echo "0"      > /proc/sys/vm/watermark_boost_factor
        # increase the watermark scale factor
        echo "125"    > /proc/sys/vm/watermark_scale_factor

        echo "${ZRAM_SERVICE} all set up"
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
        echo "${ZRAM_SERVICE} stopped"
    fi
}

case "$1" in
    "activate" ) _start_ ;;
    "deactivate" ) _restart_ ;;
esac
