#
# Makefile - build a kernel+filesystem image for stand-alone Linux booting
#
# Copyright (C) 2012 ARM Limited. All rights reserved.
#
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE.txt file.

ROOT_DIR=${.CURDIR}/..
include ${ROOT_DIR}/Makefile.inc

# VE
PHYS_OFFSET	= 0x80000000
UART_BASE	= 0x1c090000
GIC_DIST_BASE	= 0x2c001000
GIC_CPU_BASE	= 0x2c002000
CNTFRQ		= 0x01800000	# 24Mhz

#INITRD_FLAGS	= -DUSE_INITRD
CPPFLAGS	+= $(INITRD_FLAGS)

BOOTLOADER	= boot.S
MBOX_OFFSET	= 0xfff8
KERNEL		= ../kernel/kernel_loader.bin
KERNEL_OFFSET	= 0x80000
LD_SCRIPT	= model.lds.S
IMAGE		= linux-system.axf

all: $(IMAGE)

clean:
	rm -f $(IMAGE) boot.o model.lds fdt.dtb

$(IMAGE): boot.o model.lds $(KERNEL)
	$(LD) -o $@ --script=model.lds

boot.o: $(BOOTLOADER) Makefile
	$(CC) $(CPPFLAGS) -DCNTFRQ=$(CNTFRQ) -DUART_BASE=$(UART_BASE) -DSYS_FLAGS=$(SYS_FLAGS) -DGIC_DIST_BASE=$(GIC_DIST_BASE) -DGIC_CPU_BASE=$(GIC_CPU_BASE) -c -o $@ $(BOOTLOADER)

model.lds: $(LD_SCRIPT)
	$(CC) $(CPPFLAGS) -DPHYS_OFFSET=$(PHYS_OFFSET) -DMBOX_OFFSET=$(MBOX_OFFSET) -DKERNEL_OFFSET=$(KERNEL_OFFSET) -DKERNEL=$(KERNEL) -E -P -C -o ${.TARGET} ${.ALLSRC}

.PHONY: all clean
