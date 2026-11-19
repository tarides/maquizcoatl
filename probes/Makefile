# Build the probe harness against an out-of-tree build of upstream/.
#
#   make BUILD=<workdir>/build      OUT=<workdir>/probes-build   # Debug
#   make BUILD=<workdir>/build-asan OUT=<workdir>/probes-build   # ASan/UBSan
#
# BUILD is the cmake build directory of upstream/ (holds libonig.so).
# OUT receives the binaries; it must be outside the repository.
# The variant (debug or asan) is inferred from BUILD's CMAKE_C_FLAGS.

UPSTREAM ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../upstream)
BUILD    ?= $(error set BUILD to the upstream cmake build directory)
OUT      ?= $(error set OUT to an output directory outside the repository)
CC       ?= cc

SAN_FLAGS := -fsanitize=address,undefined -fno-omit-frame-pointer
IS_ASAN   := $(shell grep -q 'CMAKE_C_FLAGS:STRING=.*fsanitize=address' $(BUILD)/CMakeCache.txt && echo yes)
VARIANT   := $(if $(IS_ASAN),asan,debug)
EXTRA     := $(if $(IS_ASAN),$(SAN_FLAGS),)

HERE := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

$(OUT)/harness-$(VARIANT): $(HERE)/harness.c
	mkdir -p $(OUT)
	$(CC) -g -O0 -Wall $(EXTRA) -DBUILD_TYPE='"$(VARIANT)"' \
	  -I$(UPSTREAM)/src -o $@ $< \
	  -L$(BUILD) -Wl,-rpath,$(abspath $(BUILD)) -lonig

.PHONY: harness
harness: $(OUT)/harness-$(VARIANT)
