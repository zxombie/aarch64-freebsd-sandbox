
/*
 * This provides an easy way to load an ELF file from and AArch64 (64 bit ARM)
 * bootloader. This is used by the FreeBSD kernel to provide a simple loader.
 */
	.text
	.globl	_start
_start:
	b real_start
	.long 0		/* Reserved */
 	/* TODO: Make 0x80000 a #define: */
	.quad 0x80000	/* The load address relative to start of RAM. */
	.quad 0		/* Reserved */
	.quad 0		/* Reserved */

real_start:
	/*
	 * We know there will be a kernel at kernel_start. The problem is
	 * we need to find it's load address. As the address given to us is
	 * a virtual address we will need to translate that to a physical
	 * address. As we were built with the kernel we know it's virtual
	 * address all we need to do is figure out the delta then apply it
	 * to the entry point from the elf file.
	 */

	/* Get the address of the kernbase value */
	adr	x15, kernbase
	/* Load the value at kernbase */
	ldr	x16, [x15]

	/* Find the physical address of kernbase */
	adr	x15, kernel_start

	/* Find the difference for the virt -> phys delta */
	sub	x17, x15, x16

	/* Find the kernel entry point (at address 0x18 in the header) */
	adr	x15, kernel_start + 0x18
	ldr	x16, [x15]

	/* Load the entry point of the kernel */
	add	x15, x16, x17
	br	x15

#if 0
	/* Debug stuff */
	mov	x0, x15
	mov	x1, x16
	mov	x2, x17

	adr	x29, stack
	ldr	x29, [x29]
	mov	sp, x29
	b	start
#endif

.align 6
kernbase:	.quad KERNBASE

.align 6
stack:		.quad 0x0000000088000000


.section ".real_kernel","aw"
.globl	kernel_start
kernel_start:
.incbin "kernel.elf"

