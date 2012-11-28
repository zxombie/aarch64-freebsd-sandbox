
DIRS	= boot-wrapper-aarch64 kernel

all: ${DIRS}

clean:
.for dir in ${DIRS}
	${MAKE} -C ${dir} clean
.endfor

boot-wrapper-aarch64: kernel

${DIRS}:
	${MAKE} -C ${.TARGET}

.PHONY: boot-wrapper-aarch64 kernel
