INSTALL_PATH = ~/.local/bin

.PHONY:all
all: $(INSTALL_PATH)/usbreset $(INSTALL_PATH)/hubpower

$(INSTALL_PATH)/usbreset: usbreset.c
	gcc -o $(INSTALL_PATH)/usbreset usbreset.c

$(INSTALL_PATH)/hubpower: hubpower.c
	gcc -o $(INSTALL_PATH)/hubpower hubpower.c

.PHONY: clean
clean:
	rm -v $(INSTALL_PATH)/usbreset $(INSTALL_PATH)/hubpower
