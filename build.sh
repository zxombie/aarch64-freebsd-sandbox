#!/bin/sh

PREFIX=/mnt/aturner/freebsd/armv8/build
FBSD_SRC=/usr/home/aturner/freebsd/head

TARGET=aarch64-none-freebsd10

# TODO: Set MACHINE_ARCH and MACHINE_CPUARCH correctly from MACHINE
CROSS_MAKE_ARGS="MACHINE=arm64 MACHINE_ARCH=arm64 MACHINE_CPUARCH=arm64"
CROSS_MAKE_ARGS="${CROSS_MAKE_ARGS} CC=${PREFIX}/bin/${TARGET}-gcc"
CROSS_MAKE_ARGS="${CROSS_MAKE_ARGS} NM=${PREFIX}/bin/${TARGET}-nm"

do_binutils()
{
	cd binutils
	./configure --prefix=${PREFIX} --target=${TARGET}
	gmake
	gmake install
	cd ..
}

do_headers()
{
	mtree -deU -f ${FBSD_SRC}/etc/mtree/BSD.root.dist \
            -p ${PREFIX}/aarch64-none-freebsd10/includes >/dev/null
        mtree -deU -f ${FBSD_SRC}/etc/mtree/BSD.usr.dist \
            -p ${PREFIX}/aarch64-none-freebsd10/includes/usr >/dev/null
        mtree -deU -f ${FBSD_SRC}/etc/mtree/BSD.include.dist \
            -p ${PREFIX}/aarch64-none-freebsd10/includes/usr/include >/dev/null

	CWD=$PWD
	cd ${FBSD_SRC}

	NOFUN="-DNO_FSCHG -DWITHOUT_HTML -DWITHOUT_INFO -DNO_LINT"
	NOFUN="${NOFUN} -DWITHOUT_MAN -DWITHOUT_NLS -DNO_PROFILE"
	NOFUN="${NOFUN} -DWITHOUT_KERBEROS -DWITHOUT_RESCUE -DNO_WARNS"

	MAKE_ARGS="-m ${FBSD_SRC}/share/mk -f Makefile.inc"
	MAKE_ARGS="${MAKE_ARGS} TARGET=arm TARGET_ARCH=arm"
	MAKE_ARGS="${MAKE_ARGS} MACHINE=arm MACHINE_ARCH=arm"
	MAKE_ARGS="${MAKE_ARGS} DESTDIR=${PREFIX}/${TARGET}/includes"

	# TODO: Rewmove the requirement to be root here
	sudo make ${MAKE_ARGS} par-includes

	cd ${CWD}

	# TODO: Create the required symlinks
}

do_gcc()
{
	cd gcc/aarch64-branch

	CONFIG_ARGS=""
	CONFIG_ARGS="${CONFIG_ARGS} --prefix=${PREFIX}"
	CONFIG_ARGS="${CONFIG_ARGS} --target=${TARGET}"
	CONFIG_ARGS="${CONFIG_ARGS} --enable-languages=c"
	CONFIG_ARGS="${CONFIG_ARGS} --disable-threads"
	CONFIG_ARGS="${CONFIG_ARGS} --disable-shared"
	CONFIG_ARGS="${CONFIG_ARGS} --disable-libmudflap"
	CONFIG_ARGS="${CONFIG_ARGS} --disable-libssp"
	CONFIG_ARGS="${CONFIG_ARGS} --disable-libgomp"
	CONFIG_ARGS="${CONFIG_ARGS} --disable-libquadmath"
	CONFIG_ARGS="${CONFIG_ARGS} --with-gmp=/usr/local"
	./configure ${CONFIG_ARGS}
	gmake
	gmake install

	cd ../..
}

do_libstand()
{
	cd libstand
	make -m ${FBSD_SRC}/share/mk ${CROSS_MAKE_ARGS} -DNO_PROFILE
	cd -
}

do_loader()
{
	cd ${FBSD_SRC}/sys/boot/arm64/loader
	make -m ${FBSD_SRC}/share/mk ${CROSS_MAKE_ARGS} -DNO_PROFILE -DWITHOUT_FORTH -DLOADER_ONLY
	cd -

	cp /usr/obj${FBSD_SRC}/sys/boot/arm64/loader/loader.bin /mnt/aturner/building/armv8
}

#do_binutils
#do_headers
#do_gcc
#do_loader

