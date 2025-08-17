.POSIX:

SERV_NAME = zram
PROG_NAME = zrs
SERVICE_LOCATION_SYSV = /etc/init.d
SERVICE_LOCATION_SYSD = /etc/systemd/system
RAW_SYSV = zram.is
INIT_LSB = zram.init

SYSV_SCRIPT = $(RAW_SYSV)

PREFIX = /usr/local
MANPREFIX = $(PREFIX)/share/man

include config.mk

$(PROG_NAME):
	sed "s|@VERSION|$(VERSION)|" zram.sh > $(PROG_NAME)
	chmod 755 $(PROG_NAME)

manpage:
	sed "s|@VERSION|$(VERSION)|; s|zram.sh|$(PROG_NAME)|" \
		zram.1 > $(PROG_NAME).1

sysvserv:
	sed \
		"s|zram.sh|$(PROG_NAME)|; s|placeholder|$(PREFIX)|" \
		$(SYSV_SCRIPT) > $(SERV_NAME)

sysdserv:
	sed \
		"s|zram.sh|$(PROG_NAME)|; s|placeholder|$(PREFIX)|" \
		zram.sysd > $(SERV_NAME).service

all: $(PROG_NAME) sysvserv sysdserv manpage

install: $(PROG_NAME) manpage
	mkdir -p $(DESTDIR)$(PREFIX)/sbin
	mkdir -p $(DESTDIR)$(MANPREFIX)/man1
	cp -f $(PROG_NAME)     $(DESTDIR)$(PREFIX)/sbin/$(PROG_NAME)
	cp -f $(PROG_NAME).1   $(DESTDIR)$(MANPREFIX)/man1/$(PROG_NAME).1
	echo $(PROG_NAME) installed in $(DESTDIR)$(PREFIX)/sbin
	rm $(PROG_NAME)

install-sysv: sysvserv
	mkdir -p $(DESTDIR)$(SERVICE_LOCATION_SYSV)
	cp -f $(SERV_NAME) $(DESTDIR)$(SERVICE_LOCATION_SYSV)/
	chmod +x $(DESTDIR)$(SERVICE_LOCATION_SYSV)/$(SERV_NAME)
	echo $(SERV_NAME) installed in $(DESTDIR)$(SERVICE_LOCATION_SYSV)
	rm $(SERV_NAME)

install-sysd: sysdserv
	mkdir -p $(DESTDIR)$(SERVICE_LOCATION_SYSD)
	cp -f $(SERV_NAME).service $(DESTDIR)$(SERVICE_LOCATION_SYSD)/
	echo $(SERV_NAME).service installed in $(DESTDIR)$(SERVICE_LOCATION_SYSD)
	rm $(SERV_NAME).service

install-all: install install-sysv install-sysd

uninstall:
	rm $(DESTDIR)$(SERVICE_LOCATION_SYSV)/$(SERV_NAME)
	rm $(DESTDIR)$(SERVICE_LOCATION_SYSD)/$(SERV_NAME).service
	rm $(DESTDIR)$(PREFIX)/sbin/$(PROG_NAME)
	echo $(SERV_NAME) uninstalled from $(DESTDIR)$(SERVICE_LOCATION_SYSV)
	echo $(SERV_NAME).service uninstalled from $(DESTDIR)$(SERVICE_LOCATION_SYSD)
	echo $(PROG_NAME) uninstalled from $(DESTDIR)$(PREFIX)/sbin

clean:
	rm -f $(PROG_NAME) $(PROG_NAME).1 $(SERV_NAME) $(SERV_NAME).service

.PHONY: install uninstall clean
