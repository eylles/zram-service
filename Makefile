.POSIX:

SERV_NAME = zram
PROG_NAME = zrs
SERVICE_LOCATION_SYSV = /etc/init.d
SERVICE_LOCATION_SYSD = /etc/systemd/system
RAW_SYSV = zram.is
INIT_LSB = zram.init

SYSV_SCRIPT = $(RAW_SYSV)

PREFIX = /usr/local

include config.mk

$(PROG_NAME):
	cp zram.sh $(PROG_NAME)
	chmod 755 $(PROG_NAME)

sysvserv:
	sed \
		"s|zram.sh|$(PROG_NAME)|; s|placeholder|$(PREFIX)|" \
		$(SYSV_SCRIPT) > $(SERV_NAME)

sysdserv:
	sed \
		"s|zram.sh|$(PROG_NAME)|; s|placeholder|$(PREFIX)|" \
		zram.sysd > $(SERV_NAME).service

all: $(PROG_NAME) sysvserv sysdserv

install: $(PROG_NAME)
	mkdir -p $(PREFIX)/sbin
	cp -f $(PROG_NAME)  $(PREFIX)/sbin/$(PROG_NAME)
	echo $(PROG_NAME) installed in $(PREFIX)/sbin
	rm $(PROG_NAME)

install-sysv: sysvserv
	mkdir -p $(SERVICE_LOCATION_SYSV)
	cp -f $(SERV_NAME) $(SERVICE_LOCATION_SYSV)/
	chmod +x $(SERVICE_LOCATION_SYSV)/$(SERV_NAME)
	echo $(SERV_NAME) installed in $(SERVICE_LOCATION_SYSV)
	rm $(SERV_NAME)

install-sysd: sysdserv
	mkdir -p $(SERVICE_LOCATION_SYSD)
	cp -f $(SERV_NAME).service $(SERVICE_LOCATION_SYSD)/
	echo $(SERV_NAME).service installed in $(SERVICE_LOCATION_SYSD)
	rm $(SERV_NAME).service

install-all: install install-sysv install-sysd

uninstall:
	rm $(SERVICE_LOCATION_SYSV)/$(SERV_NAME)
	rm $(SERVICE_LOCATION_SYSD)/$(SERV_NAME).service
	rm $(PREFIX)/sbin/$(PROG_NAME)
	echo $(SERV_NAME) uninstalled from $(SERVICE_LOCATION_SYSV)
	echo $(SERV_NAME).service uninstalled from $(SERVICE_LOCATION_SYSD)
	echo $(PROG_NAME) uninstalled from $(PREFIX)/sbin

clean:
	rm $(PROG_NAME)
	rm $(SERV_NAME)
	rm $(SERV_NAME).service

.PHONY: install uninstall clean
