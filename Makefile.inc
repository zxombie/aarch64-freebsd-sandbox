
CROSS_COMPILE  ?= ${ROOT_DIR}/toolchain/build/bin/aarch64-none-freebsd10-
CC		= $(CROSS_COMPILE)gcc
LD		= $(CROSS_COMPILE)ld
OBJCOPY		= ${CROSS_COMPILE}objcopy

