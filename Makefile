PREFIX ?= /usr/local
BINARY_NAME = apfel-clip

.PHONY: build install clean

build:
	swift build -c release

install: build
	@mkdir -p $(PREFIX)/bin
	@if [ -w "$(PREFIX)/bin" ]; then \
		install .build/release/$(BINARY_NAME) $(PREFIX)/bin/$(BINARY_NAME); \
	else \
		sudo install .build/release/$(BINARY_NAME) $(PREFIX)/bin/$(BINARY_NAME); \
	fi
	@echo "Installed $(BINARY_NAME) to $(PREFIX)/bin/$(BINARY_NAME)"

clean:
	swift package clean
	rm -rf .build
