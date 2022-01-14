# ZRAM service

this is a simple init script compatible with sysvinit to set up zram.

this script depends on a posix shell interpreter, core utilities and zramctl

## why ?

looked at other services and scripts for using zram and they were a mess to be
honest


## usage

the makefile should put the script in `/etc/init.d/zram` by default, after that
a simple ```sh sudo update-rc.d zram defaults``` should be enough to activate
it for the next boot

the service script supports the start, stop, restart and status actions along
the init, end, stat and force-restart aliases.


## TODO

* make a release
* add debian packaging "paperwork"
* perhaps add an action in the makefile to create a .deb

