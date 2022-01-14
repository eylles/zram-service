NAME = zram
LOCATION = /etc/init.d

install:
	mkdir -p $(LOCATION)
	cp -f zram.sh $(LOCATION)/$(NAME)
	chmod 755 $(LOCATION)/$(NAME)
	echo $(NAME) installed in $(LOCATION)

uninstall:
	rm $(NAME) $(LOCATION)/$(NAME)
	echo $(NAME) uninstalled from $(LOCATION)

.PHONY: install uninstall
