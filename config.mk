# zrs version
VERSION = 0.1.1

# PREFIX for install
PREFIX = /usr/local
MANPREFIX = $(PREFIX)/share/man

# sysvinit scripts available
RAW_SYSV = zram.is
INIT_LSB = zram.init

# sysvinit script of choice
SYSV_SCRIPT = $(RAW_SYSV)
