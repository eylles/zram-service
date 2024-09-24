SERV_NAME = zram
PROG_NAME = zrs
SERVICE_LOCATION_SYSV = /etc/init.d
PREFIX = /usr/local

install:
	mkdir -p $(PREFIX)/sbin
	cp -f zram.sh  $(PREFIX)/sbin/$(PROG_NAME)
	chmod 755 $(PREFIX)/sbin/$(PROG_NAME)
	echo $(PROG_NAME) installed in $(PREFIX)/sbin

	mkdir -p $(SERVICE_LOCATION_SYSV)
	cp -f zram.is $(SERVICE_LOCATION_SYSV)/$(SERV_NAME)
	chmod 755 $(SERVICE_LOCATION_SYSV)/$(SERV_NAME)
	echo $(SERV_NAME) installed in $(SERVICE_LOCATION_SYSV)

uninstall:
	rm $(SERV_NAME) $(SERVICE_LOCATION_SYSV)/$(SERV_NAME)
	echo $(NAME) uninstalled from $(SERVICE_LOCATION_SYSV)

.PHONY: install uninstall
