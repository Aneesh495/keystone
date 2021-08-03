# Keystone Automation Makefile

CC ?= clang
CFLAGS ?= -O3 -Wall -Wextra -std=c99 -fPIC
DYLIB_EXT ?= dylib
UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Linux)
    DYLIB_EXT = so
    SHARED_FLAGS = -shared
endif
ifeq ($(UNAME_S),Darwin)
    DYLIB_EXT = dylib
    SHARED_FLAGS = -dynamiclib
endif

.PHONY: all build build-native build-bench start stop status health test bench verify clean

all: build-native test

build: build-native

build-native:
	$(MAKE) -C native all
	@mkdir -p lib bin
	@cp -f native/lib/* lib/ 2>/dev/null || true
	@cp -f native/bin/* bin/ 2>/dev/null || true
	@echo "Native library and benchmark synced to lib/ and bin/"

build-bench: build-native

start:
	@./scripts/run.sh

stop:
	@./bin/keystone stop

status:
	@./bin/keystone status

health:
	@./bin/keystone health

test:
	@./scripts/test.sh

bench: build-bench
	@./scripts/bench.sh

verify:
	@./scripts/verify.sh

clean:
	rm -rf lib/*.dylib lib/*.so bin/keystone_bench storage/test_* app/transactions/storage/
	@echo "Clean completed."
