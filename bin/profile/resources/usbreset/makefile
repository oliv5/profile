INSTALLED_BIN = ~/.local/bin/usbreset

$(INSTALLED_BIN): usbreset.c
	gcc -o $(INSTALLED_BIN) usbreset.c

.PHONY: clean
clean:
	rm -v $(INSTALLED_BIN)
