CC ?= clang
CFLAGS ?= -O3 -Wall -Wextra -pedantic -std=c11 -fPIC -Iinclude
LDFLAGS ?=

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    DYLIB_EXT := dylib
    SHARED_FLAG := -dynamiclib
else
    DYLIB_EXT := so
    SHARED_FLAG := -shared
endif

TARGET_LIB := lib/libkeystone_accel.$(DYLIB_EXT)
BENCH_BIN := bin/keystone_bench

SRCS := src/simd_scan.c src/keystone_accel.c
OBJS := $(SRCS:.c=.o)

.PHONY: all clean bench

all: $(TARGET_LIB) $(BENCH_BIN)

$(TARGET_LIB): $(OBJS)
	@mkdir -p lib
	$(CC) $(SHARED_FLAG) -o $@ $^ $(LDFLAGS)
	@echo "Built shared acceleration library: $@"

$(BENCH_BIN): src/benchmark.o $(OBJS)
	@mkdir -p bin
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)
	@echo "Built benchmark binary: $@"

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

bench: $(BENCH_BIN)
	@./$(BENCH_BIN)

clean:
	rm -rf src/*.o lib bin
