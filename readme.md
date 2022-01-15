# ZRAM service

this is a simple init script compatible with sysvinit to set up zram.

this script depends on a posix shell interpreter, core utilities and zramctl


<p align="center">
<a href="https://github.com/eylles/zram-service" alt="GitHub"><img src="https://img.shields.io/badge/Github-2B3137?style=for-the-badge&logo=Github&logoColor=FFFFFF"></a>
<a href="https://gitlab.com/eylles/zram-service" alt="GitLab"><img src="https://img.shields.io/badge/Gitlab-380D75?style=for-the-badge&logo=Gitlab"></a>
<a href="https://codeberg.org/eylles/zram-service" alt="CodeBerg"><img src="https://img.shields.io/badge/Codeberg-2185D0?style=for-the-badge&logo=codeberg&logoColor=F2F8FC"></a>
</p>

## why ?

looked at other services and scripts for using zram and they were a mess to be
honest


## usage

the makefile should put the script in `/etc/init.d/zram` by default, after that
a simple ```sudo update-rc.d zram defaults``` should be enough to activate
it for the next boot

the service script supports the start, stop, restart and status actions along
the init, end, stat and force-restart aliases.


## TODO

* make a release
* add debian packaging "paperwork"
* perhaps add an action in the makefile to create a .deb

