#!/bin/sh

# PATH should only include /usr/* if it runs after the mountnfs.sh
# script.  Scripts running before mountnfs.sh should remove the /usr/*
# entries.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

# service name
ZRAM_SERVICE=zram
# distro vendor service config file
VENDOR_CONFIG=/etc/default/zram-config
# machine administrator service config file
ADMIN_CONFIG=/etc/zram-config
# the available config to use
ZRAM_CONFIG=""

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
# most compression algorithms can achieve 2x compression tops
ram_perc_max=200
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

# zram0
zrdevice=zram0

echo () { printf %s\\n "$*" ; }

# usage: is_int "number"
is_int() {
    if [ -n "$1" ]; then
        printf %d "$1" >/dev/null 2>&1
    else
        return 1
    fi
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

# usage: set_zrdev device size streams algorithm
#
#        device: device nameindex i.e. zram0
#          size: device size in bytes
#       streams: compression streams i.e. 8
#     algorithm: compression algorithm i.e. lz4
set_zrdev () {
    device="$1"
    size="$2"
    streams="$3"
    algorithm="$4"

    # wait for the required zram files to be created
    until [ -e "/sys/block/${device}/disksize" ] && [ -e "/dev/${device}" ]
    do
        sleep 1
    done

    if [ -x /usr/sbin/zramctl ]; then
        # use zramctl
        zramctl "/dev/${device}" -s "$size" -t "$streams" -a "$algorithm"
    else
        # do this manually
        echo "$size"      > "/sys/block/${device}/disksize"
        echo "$streams"   > "/sys/block/${device}/max_comp_streams"
        echo "$algorithm" > "/sys/block/${device}/comp_algorithm"
    fi
}

# usage rem_zrdev index
#
#         index: device index i.e. 0
rem_zrdev () {
    index="$1"
    if [ -x /usr/sbin/zramctl ]; then
        # use zramctl
        zramctl -r "/dev/zram${index}"
    else
        # do it manually
        echo "$index" > "/sys/class/zram-control/hot_remove"
    fi
}

_start_() {
    if grep -q zram /proc/swaps; then
        echo "${ZRAM_SERVICE} already set up, exiting"
        return 1
    else
        # calculate streams
        STREAMS=$(grep -c ^processor /proc/cpuinfo)

        if [ -r "$VENDOR_CONFIG" ]; then
            ZRAM_CONFIG="$VENDOR_CONFIG"
        fi
        if [ -r "$ADMIN_CONFIG" ]; then
            ZRAM_CONFIG="$ADMIN_CONFIG"
        fi
        # Read get values from config if present
        if [ -n "$ZRAM_CONFIG" ]; then
            echo "loading config"
            ALGORITHM=$(getval "ALGORITHM" "$ZRAM_CONFIG")
            RAM_PERCENTAGE=$(getval "RAM_PERCENTAGE" "$ZRAM_CONFIG")
            PRIORITY=$(getval "PRIORITY" "$ZRAM_CONFIG")
            MEM_LIMIT_PERCENTAGE=$(getval "MEM_LIMIT_PERCENTAGE" "$ZRAM_CONFIG")
        fi

        # make sure algo from config is valid
        case "$ALGORITHM" in
            lzo|lzo-rle|lz4|lz4hc|zstd|deflate|842)
                # zstd can achieve a 4x compression
                if [ "$ALGORITHM" = "zstd" ]; then
                    ram_perc_max=400
                fi
                ;;
            *)
                echo "warning: invalid compression algorithm, using default."
                echo "algorithm: $default_ALGORITHM"
                # use default
                ALGORITHM=$default_ALGORITHM
                ;;
        esac

        # check if the algorithm is already loaded
        if grep -q "$ALGORITHM" /proc/modules; then
            # check if algorithm loads
            if modprobe -n "$ALGORITHM" 2>/dev/null; then
                modprobe "$ALGORITHM"
            else
                modprobe "$default_ALGORITHM"
            fi
        fi
        modprobe zram num_devices=1

        # check that the numeric values from config are int
        if ! is_int "$RAM_PERCENTAGE"; then
            echo "using default ram percentage: $default_RAM_PERCENTAGE"
            RAM_PERCENTAGE=$default_RAM_PERCENTAGE
        fi

        if ! is_int "$PRIORITY"; then
            echo "using default priority: $default_PRIORITY"
            PRIORITY=$default_PRIORITY
        fi

        if ! is_int "$MEM_LIMIT_PERCENTAGE"; then
            echo "using default mem limit: $default_MEM_LIMIT_PERCENTAGE"
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
        ZRAM_DISK_SIZE=$(( MEMORY_TOTAL * RAM_PERCENTAGE / 100 ))

        set_zrdev "${zrdevice}" "$ZRAM_DISK_SIZE" "$STREAMS" "$ALGORITHM"

        echo "waiting for zram device"
        until [ -b "/dev/${zrdevice}" ]; do
            sleep 1
        done

        if [ "${MEM_LIMIT_PERCENTAGE}" -gt 0 ]; then
            MEM_LIMIT_SIZE=$(( MEMORY_TOTAL * MEM_LIMIT_PERCENTAGE / 100 ))
            echo "${MEM_LIMIT_SIZE}" > "/sys/block/${zrdevice}/mem_limit"
        fi

        echo "zram device initiated"
        echo "activating device"
        mkswap -L "SWAP_ZRAM_0" "/dev/${zrdevice}" && echo "zram device labeled"
        sleep 1
        swapon -p "$PRIORITY" "/dev/${zrdevice}" && echo "zram device activated"

        echo "optimizing zram environment"
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

        # set min free kb to %1 of system memory to completely eliminate the
        # possibility of system freezes
        MINIMUM=$(awk '/MemTotal/ {printf "%.0f", $2 * 0.01}' /proc/meminfo)
        CURRENT=$(cat /proc/sys/vm/min_free_kbytes)
        min "$CURRENT" "$MINIMUM" > /proc/sys/vm/min_free_kbytes

        echo "${ZRAM_SERVICE} all set up"
    fi
}

_stop_() {
    if ! grep -c "/dev/zram" /proc/swaps >/dev/null; then
        echo "${ZRAM_SERVICE} NOT running, exiting"
        return 1
    else
        for n in $(seq $(grep -c "/dev/zram" /proc/swaps))
        do
            INDEX=$((n - 1))
            echo "deactivating /dev/zram$INDEX"
            swapoff /dev/zram$INDEX && echo "/dev/zram$INDEX deactivated"
            sleep 1
            rem_zrdev "$INDEX"
        done

        wait
        sleep 1
        modprobe -r zram
        echo "${ZRAM_SERVICE} stopped"
    fi
}

_status_() {
    running=0
    dead=1
    if ! grep -c "/dev/zram" /proc/swaps >/dev/null; then
        echo "${ZRAM_SERVICE} is not set"
        return "$dead"
    else
        echo "${ZRAM_SERVICE} is set"
        return "$running"
    fi
}

myname="${0##*/}"

show_usage () {
    printf '%s\n'   "Usage:"
    printf '\t%s %s\n' "${myname}" "{activate|set|deactivate|unset|status}"
}

version="@VERSION"

show_version () {
    printf '%s\n' "$version"
}

case "$1" in
    activate|set) _start_ ;;
    deactivate|unset) _stop_ ;;
    status) _status_ ;;
    version|-v|--version) show_version ;;
    *) show_usage ;;
esac
