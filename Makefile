PACKAGE = git
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = prefix=/usr gitexecdir=/usr/lib/git-core
CONF_FLAGS = NO_TCLTK=1 NO_PYTHON=1 NO_EXPAT=1 NO_GETTEXT=1

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/v//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

OPENSSL_VERSION = 1.0.2e-2
OPENSSL_URL = https://github.com/amylum/openssl/releases/download/$(OPENSSL_VERSION)/openssl.tar.gz
OPENSSL_TAR = /tmp/openssl.tar.gz
OPENSSL_DIR = /tmp/openssl

ZLIB_VERSION = 1.2.8-1
ZLIB_URL = https://github.com/amylum/zlib/releases/download/$(ZLIB_VERSION)/zlib.tar.gz
ZLIB_TAR = /tmp/zlib.tar.gz
ZLIB_DIR = /tmp/zlib

CURL_VERSION = 7.45.0-1
CURL_URL = https://github.com/amylum/curl/releases/download/$(CURL_VERSION)/curl.tar.gz
CURL_TAR = /tmp/curl.tar.gz
CURL_DIR = /tmp/curl

CFLAGS = -I$(CURL_DIR)/usr/include -I$(OPENSSL_DIR)/usr/include -I$(ZLIB_DIR)/usr/include
LDFLAGS = -L$(CURL_DIR)/usr/lib -L$(OPENSSL_DIR)/usr/lib -L$(ZLIB_DIR)/usr/lib -static
LIB_PATH = $(CURL_DIR)/usr/lib/libcurl.a $(OPENSSL_DIR)/usr/lib/libssl.a $(OPENSSL_DIR)/usr/lib/libcrypto.a

.PHONY : default submodule deps manual container deps build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(OPENSSL_DIR) $(OPENSSL_TAR)
	mkdir $(OPENSSL_DIR)
	curl -sLo $(OPENSSL_TAR) $(OPENSSL_URL)
	tar -x -C $(OPENSSL_DIR) -f $(OPENSSL_TAR)
	rm -rf $(ZLIB_DIR) $(ZLIB_TAR)
	mkdir $(ZLIB_DIR)
	curl -sLo $(ZLIB_TAR) $(ZLIB_URL)
	tar -x -C $(ZLIB_DIR) -f $(ZLIB_TAR)
	rm -rf $(CURL_DIR) $(CURL_TAR)
	mkdir $(CURL_DIR)
	curl -sLo $(CURL_TAR) $(CURL_URL)
	tar -x -C $(CURL_DIR) -f $(CURL_TAR)

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	cd $(BUILD_DIR) && make CC='musl-gcc -static' CURL_LIBCURL='$(LIB_PATH)' $(PATH_FLAGS) $(CONF_FLAGS) CFLAGS='$(CFLAGS)' LDFLAGS='$(LDFLAGS)' DESTDIR=$(RELEASE_DIR) all install
	rm -rf $(RELEASE_DIR)/tmp
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

