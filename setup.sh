#!/bin/sh

set -e

DIRNAME=`dirname $0`
CWD=`realpath ${DIRNAME}`
PREFIX=${CWD}/toolchain
BUILD_PREFIX=${PREFIX}/build

TARGET=aarch64-none-freebsd10

update_git()
{
	subdir=$1

	cd ${PREFIX}
	if [ ! -d "${subdir}" ] ; then
		git clone git://github.com/zxombie/${subdir}.git
	else
		cd ${subdir}
		git pull
	fi
	cd ${CWD}
}

update_binutils()
{
	update_git aarch64-freebsd-binutils
}

build_binutils()
{
	cd ${PREFIX}/aarch64-freebsd-binutils
	./configure --prefix=${BUILD_PREFIX} --target=${TARGET}
	gmake
	gmake install
	cd ${CWD}
}

update_gcc()
{
	update_git aarch64-freebsd-gcc
}

build_gcc()
{
	mkdir -p ${PREFIX}/aarch64-freebsd-gcc-build
	cd ${PREFIX}/aarch64-freebsd-gcc-build

	CONFIG_ARGS=""
	CONFIG_ARGS="${CONFIG_ARGS} --prefix=${BUILD_PREFIX}"
	CONFIG_ARGS="${CONFIG_ARGS} --target=${TARGET}"
	CONFIG_ARGS="${CONFIG_ARGS} --enable-languages=c"
	CONFIG_ARGS="${CONFIG_ARGS} --disable-threads"
	CONFIG_ARGS="${CONFIG_ARGS} --disable-shared"
	CONFIG_ARGS="${CONFIG_ARGS} --disable-libmudflap"
	CONFIG_ARGS="${CONFIG_ARGS} --disable-libssp"
	CONFIG_ARGS="${CONFIG_ARGS} --disable-libgomp"
	CONFIG_ARGS="${CONFIG_ARGS} --disable-libquadmath"
	CONFIG_ARGS="${CONFIG_ARGS} --with-gmp=/usr/local"
	${PREFIX}/aarch64-freebsd-gcc/aarch64-branch/configure ${CONFIG_ARGS}

	# Only build gcc, skip libgcc for now
	gmake all-gcc
	gmake install-gcc

	cd ${CWD}
}

cd ${CWD}
mkdir -p ${BUILD_PREFIX}

update_binutils
build_binutils
update_gcc
build_gcc

