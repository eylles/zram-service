# ZRAM service

This is a simple init script compatible with sysvinit to set up zram.

This script depends on a posix shell interpreter, core utilities and zramctl


<p align="center">
<a href="https://github.com/eylles/zram-service" alt="GitHub"><img src="https://img.shields.io/badge/Github-2B3137?style=for-the-badge&logo=Github&logoColor=FFFFFF"></a>
<a href="https://gitlab.com/eylles/zram-service" alt="GitLab"><img src="https://img.shields.io/badge/Gitlab-380D75?style=for-the-badge&logo=Gitlab"></a>
<a href="https://codeberg.org/eylles/zram-service" alt="CodeBerg"><img src="https://img.shields.io/badge/Codeberg-2185D0?style=for-the-badge&logo=codeberg&logoColor=F2F8FC"></a>
<br>
<br>
<a href="./LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green.svg"></a>
<a href="https://liberapay.com/eylles/donate"><img alt="Donate using Liberapay" src="https://img.shields.io/liberapay/receives/eylles.svg?logo=liberapay"></a>
<a href="https://liberapay.com/eylles/donate"><img alt="Donate using Liberapay" src="https://img.shields.io/liberapay/patrons/eylles.svg?logo=liberapay"></a>
</p>

## why ?

Looked at other services and scripts for using zram and they were a mess to be
honest, some did too much others too little, this won't be the be all end all of
zram scripts and setups but so long as it serves most cases i am satisfied.


## installation

Install everything:
```sh
sudo make install-all
```
this will provide:
|component|default location|description|
|----|----|----|
|zrs|`/usr/local/sbin/zrs`|script that does the actual work of config parsing and zram setting|
|zram|`/etc/init.d/zram`|sysvinit initscript|
|zram.service|`/etc/systemd/system/zram.service`|systemd unit|


## Usage

### sysvinit

The makefile should put the script in `/etc/init.d/zram` by default, after that
a simple ```sudo update-rc.d zram defaults``` should be enough to activate
it for the next boot

The service script supports the start, stop, restart and status actions along
the init, end, stat and force-restart aliases.

A simple `sudo service zram start` will initiate the zram service.


### systemd

The makefile should put the unit in `/etc/systemd/system/zram.service` by
default, all you need is run ```sudo systemctl enable zram``` to activate the
service for the next boot.

Initiate the service with `sudo systemctl start zram`


## TODO

* make a release
* add debian packaging "paperwork"
* perhaps add an action in the makefile to create a .deb

