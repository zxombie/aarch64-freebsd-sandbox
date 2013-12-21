
ROOT_DIR=${.CURDIR}/..
include ${ROOT_DIR}/Makefile.inc

LOADER_OBJECTS=linux_start.o
OBJECTS=locore.o test.o

CFLAGS=-DKERNBASE=0xffffff8080100000
#CFLAGS=-DKERNBASE=0x0000000080100000

all: kernel_loader.bin

clean:
	rm -fr ${OBJECTS} ${LOADER_OBJECTS} kernel_loader.bin \
	    kernel_loader.elf kernel.elf

.PHONY: all clean

kernel_loader.bin: kernel_loader.elf
	${OBJCOPY} -O binary ${.ALLSRC} ${.TARGET}

kernel_loader.elf: ${LOADER_OBJECTS} kernel.elf
	${LD} -Bdynamic -T ldscript.arm64_noheader -o ${.TARGET} ${LOADER_OBJECTS}
linux_start.o: kernel.elf

kernel.elf: ${OBJECTS}
	${LD} -Bdynamic -T ldscript.arm64 -o ${.TARGET} ${.ALLSRC}

%.o.c:
	${CC} ${CFLAGS} -c ${.IMPSRC}

%.o.S:
	${CC} ${CFLAGS} -c ${.IMPSRC}
