aarch64-freebsd-sandbox
=======================

Sandbox to play with AArch64 for FreeBSD.

To test this a FreeBSD and Linux machine are required. The FreeBSD machine
will be used to build the code, the Linux machine will fun it in the ARMv8
Foundation Model software and needs to be running a
64-bit version of Linux.

## Building

You will need a FreeBSD toolchain targeted for AArch64. The setup.sh script
will download and build a copy of binutils and GCC patched for FreeBSD.

### Build procedure

The build uses FreeBSD make. It may not work on other operating systems.

After fetching the sandbox source run the following:
```shell
sh setup.sh
make
```

* setup.sh only needs to be run once.
* make will build the test kernel and foundation model loader

### Running

Download the ARMv8 Foundation Model software from http://www.arm.com/fvp.

To run:
```shell
/path/to/model/Foundation_v8 --image /path/to/sandbox/boot-wrapper-aarch64/linux-system.axf
```

Where /path/to/model is the location of the ARMv8 Foundation Model and
/path/to/sandbox is the location of this code.

## Toolchain

The patch toolchain are available from:
* binutils: https://github.com/zxombie/aarch64-freebsd-binutils
* GCC: https://github.com/zxombie/aarch64-freebsd-gcc

The setup script will automatically download and build them, there is no need
to do it manually.

## External tools
* The foundation model is available from: http://www.arm.com/fvp
* The boot-wrapper-aarch64 is modified from: git://git.kernel.org/pub/scm/linux/kernel/git/cmarinas/boot-wrapper-aarch64.git

