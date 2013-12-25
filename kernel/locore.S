/*-
 * Copyright (c) 2012, 2013 Andrew Turner
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $FreeBSD$
 */

#include "param.h"

#include "asm.h"
#include "pte.h"

	.globl	kernbase
	.set	kernbase, KERNBASE

#define	INIT_STACK_SIZE	(PAGE_SIZE * 4)

/*
 * This follows the Linux call convention.
 * XXX: This may change.
 *
 * We can assume:
 *  MMU      off
 *  D-Cache: off
 *  I-Cache: on or off
 *  We are loaded at RAM_BASE + 0x80000
 */
	.text
	.globl _start
_start:
	/* Drop to EL1 */
	bl	drop_to_el1

	/* Get the virt -> phys offset */
	bl	get_virt_delta

	/*
	 * At this point:
	 * x29 = PA - VA
	 * x28 = Our physical load address
	 */

	/* Create the page tables */
	bl	create_pagetables

	/* Enable the mmu */
	bl	start_mmu

	ldr	x29, .Lvirtdone
	br	x29

virtdone:

	/* Load the initial stack */
	adr	x29, init_stack
	add	x29, x29, INIT_STACK_SIZE
	mov	sp, x29

	b	start

.Lvirtdone:
	.quad	virtdone

	.bss
init_stack:
	.space	INIT_STACK_SIZE

	.text
drop_to_el1:
	mrs	x1, CurrentEL
	lsr	x1, x1, #2
	cmp	x1, #0x2
	b.eq	1f
	ret
1:
	/* Configure the Hypervisor */
	mov	x2, #(HCR_RW)
	msr	hcr_el2, x2

	/* Load the Virtualization Process ID Register */
	mrs	x2, midr_el1
	msr	vpidr_el2, x2

	/* Load the Virtualization Multiprocess ID Register */
	mrs	x2, mpidr_el1
	msr	vmpidr_el2, x2

	/* Set the bits that need to be 1 in sctlr_el1 */
	ldr	x2, =(SCTLR_RES1)
	msr	sctlr_el1, x2

	/* Don't trap to EL2 for exceptions */
	mov	x2, #CPTR_LOWER
	msr	cptr_el2, x2

	/* Don't trap to EL2 for CP15 traps */
	msr	hstr_el2, xzr

	msr	vbar_el2, xzr

	/* Hypervisor trap functions */
	adr	x2, hyp_vectors
	msr	vbar_el2, x2

	mov	x2, #(PSR_F | PSR_I | PSR_A | PSR_D | PSR_M_EL1h)
	msr	spsr_el2, x2
	msr	elr_el2, x30

	eret

#define	VECT_ENTRY(x)	\
    .align 7;		\
    b	x

	.text
	.align 11
hyp_vectors:
	VECT_ENTRY(hyp_trap_invalid)	/* Synchronous EL2t */
	VECT_ENTRY(hyp_trap_invalid)	/* IRQ EL2t */
	VECT_ENTRY(hyp_trap_invalid)	/* FIQ EL2t */
	VECT_ENTRY(hyp_trap_invalid)	/* Error EL2t */

	VECT_ENTRY(hyp_trap_invalid)	/* Synchronous EL2h */
	VECT_ENTRY(hyp_trap_invalid)	/* IRQ EL2h */
	VECT_ENTRY(hyp_trap_invalid)	/* FIQ EL2h */
	VECT_ENTRY(hyp_trap_invalid)	/* Error EL2h */

	VECT_ENTRY(hyp_trap_sync)	/* Synchronous 64-bit EL1 */
	VECT_ENTRY(hyp_trap_invalid)	/* IRQ 64-bit EL1 */
	VECT_ENTRY(hyp_trap_invalid)	/* FIQ 64-bit EL1 */
	VECT_ENTRY(hyp_trap_invalid)	/* Error 64-bit EL1 */

	VECT_ENTRY(hyp_trap_invalid)	/* Synchronous 32-bit EL1 */
	VECT_ENTRY(hyp_trap_invalid)	/* IRQ 32-bit EL1 */
	VECT_ENTRY(hyp_trap_invalid)	/* FIQ 32-bit EL1 */
	VECT_ENTRY(hyp_trap_invalid)	/* Error 32-bit EL1 */

	.data
hyp_trap_invalid:
	b	hyp_trap_invalid

	.text
/* TODO: This is broken with the move to ttbr1 */
hyp_trap_sync:
	ldr	x29, =0x88000000
	mov	sp, x29

	ldr	x0, =0xffffff8088000000
#if 1
	at	s12e1w, x0
	mrs	x0, par_el1
	ldr	w1, =16
	bl	puthex
	1: b	1b
#endif

	mrs	x0, ttbr0_el1
	ldr	w1, =16
	bl	puthex
	1: b	1b

	ldr	x1, =(0x1c090000)
	ldr	x2, =(0x41)
	str	x2, [x1]
	1: b	1b

/*
 * Get the delta between the physical address we were loaded to and the
 * virtual address we expect to run from. This is used when building the
 * initial page table.
 */
get_virt_delta:
	/* Load the physical address of virt_map */
	adr	x29, virt_map
	/* Load the virtual address of virt_map stored in virt_map */
	ldr	x28, [x29]
	/* Find PA - VA as PA' = VA' - VA + PA = VA' + (PA - VA) = VA' + x29 */
	sub	x29, x29, x28
	/* Find the load address for the kernel */
	ldr	x28, =KERNBASE
	add	x28, x28, x29
	ret

	.align 3
virt_map:
	.quad	virt_map

/*
 * This builds the page tables containing the identity map, and the kernel
 * virtual map.
 *
 * It relys on:
 *  We were loaded to an address that is on a 2MiB boundary
 *  All the memory must not cross a 1GiB boundaty
 *  x28 contains the physical address we were loaded from
 *
 * TODO: This is out of date.
 *  There are at least 5 pages before that address for the page tables
 *   The pages used are:
 *    - The identity (PA = VA) table (TTBR0)
 *    - The Kernel L1 table          (TTBR1)(not yet)
 *    -  The PA != VA L2 table to jump into (not yet)
 *    -  The FDT L2 table                   (not yet)
 */
create_pagetables:
	/* Save the Link register */
	mov	x5, x30

	ldr	x15, =(PAGE_SIZE * 3)
	/* x27 = The level 1 page table */
	sub	x27, x28, x15

	/* Clean the page table */
	mov	x6, x27
1:
	stp	xzr, xzr, [x6], #16
	stp	xzr, xzr, [x6], #16
	stp	xzr, xzr, [x6], #16
	stp	xzr, xzr, [x6], #16
	cmp	x6, x28
	b.lo	1b

	ldr	x15, =(PAGE_SIZE)
	/* Create the VA = PA map */
	mov	x6, x27		/* The initial page table */
	ldr	x7, =1
	mov	x9, x27
	mov	x8, x9		/* VA start (== PA start) */
	
	bl	build_section_pagetable

	/* Create a table for the UART */
	ldr	x7, =0
	mov	x8, 0x10000000		/* VA start (== PA start) */
	mov	x9, 0x10000000		/* PA start */
	
	bl	build_section_pagetable

	/* Build the TTBR1 maps */
	sub	x26, x27, x15

	/* Create the kernel space L2 table */
	sub	x6, x26, #(PAGE_SIZE)
	ldr	x7, =1
	ldr	x8, =(KERNBASE & L2_OUT_MASK)
	mov	x9, x28
	bl	build_block_pagetable

	mov	x9, x6
	mov	x6, x26
	bl	map_l1_pagetable

	/* Restore the Link register */
	mov	x30, x5
	ret

/*
 * Builds a 1 GiB page table entry
 *  x6 = L1 table
 *  x7 = Type (0 = Device, 1 = Normal)
 *  x8 = VA start
 *  x9 = PA start (trashed)
 *  x11, x12 and x13 are trashed
 */
build_section_pagetable:
	/*
	 * Build the L1 table entry.
	 */
	/* Find the table index */
	lsr	x11, x8, #L1_SHIFT
	and	x11, x11, #L1_IDX_MASK

	/* Build the L1 block entry */
	lsl	x12, x7, #2
	orr	x12, x12, #L1_BLOCK
	orr	x12, x12, #(1 << 10) // AF bit

	/* Only use the output address bits */
	ldr	x13, =(L1_OUT_MASK)
	and	x9, x9, x13
	orr	x12, x12, x9

	/* Store the entry */
	str	x12, [x6, x11, lsl #3]

	ret

/*
 * Builds an L1 -> L2 table descriptor
 *
 * This is a map for a 2GiB block of memory with up to 2MiB regions mapped
 * within it by build_block_pagetable.
 *
 *  x6  = L1 table
 *  x8  = Virtual Address
 *  x9  = L2 PA
 *  x11, x12 and x13 are trashed
 */
map_l1_pagetable:
	/*
	 * Map an L1 -> L2 table entry.
	 */
	/* Find the table index */
	lsr	x11, x8, #L1_SHIFT
	and	x11, x11, #L1_IDX_MASK

	/* Build the L1 block entry */
	orr	x12, x7, #L1_TABLE

	/* Only use the output address bits */
	ldr	x13, =(L1_TBL_MASK)
	and	x9, x9, x13
	orr	x12, x12, x9

	/* Store the entry */
	str	x12, [x6, x11, lsl #3]

	ret

/*
 * Builds count 2 MiB page table entry
 *  x6  = L2 table
 *  x7  = Type (0 = Device, 1 = Normal)
 *  x8  = VA start
 *  x9  = PA start (trashed)
 *  x10 = Entry count (TODO)
 *  x11, x12 and x13 are trashed
 */
build_block_pagetable:
	/*
	 * Build the L2 table entry.
	 */
	/* Find the table index */
	lsr	x11, x8, #L2_SHIFT
	and	x11, x11, #L2_IDX_MASK

	/* Build the L2 block entry */
	lsl	x12, x7, #2
	orr	x12, x12, #L2_BLOCK
	orr	x12, x12, #(1 << 10) // AF bit

	/* Only use the output address bits */
	ldr	x13, =(L2_OUT_MASK)
	and	x9, x9, x13
	orr	x12, x12, x9

	/* Store the entry */
	str	x12, [x6, x11, lsl #3]

	ret

#define	MAIR(attr, idx) ((attr) << ((idx) * 8))

#define	VIRT_BITS	38

#define	TCR_ASID_16	(1 << 36)

#define	TCR_IPS_SHIFT	32
#define	TCR_IPS_32BIT	(0 << TCR_IPS_SHIFT)
#define	TCR_IPS_36BIT	(1 << TCR_IPS_SHIFT)
#define	TCR_IPS_40BIT	(2 << TCR_IPS_SHIFT)
#define	TCR_IPS_42BIT	(3 << TCR_IPS_SHIFT)
#define	TCR_IPS_44BIT	(4 << TCR_IPS_SHIFT)
#define	TCR_IPS_48BIT	(5 << TCR_IPS_SHIFT)

#define	TCR_TG1_SHIFT	30
#define	TCR_TG1_16K	(1 << TCR_TG1_SHIFT)
#define	TCR_TG1_4K	(2 << TCR_TG1_SHIFT)
#define	TCR_TG1_64K	(3 << TCR_TG1_SHIFT)

#define	TCR_T1SZ_SHIFT	16
#define	TCR_T0SZ_SHIFT	0
#define	TCR_TxSZ(x)	(((x) << TCR_T1SZ_SHIFT) | ((x) << TCR_T0SZ_SHIFT))

#define	SCTLR_SET_BITS	(SCTLR_UCI | SCTLR_nTWE | SCTLR_nTWI | SCTLR_UCT | \
    SCTLR_DZE | SCTLR_I | SCTLR_SED | SCTLR_M)
#define	SCTLR_CLEAR_BITS (SCTLR_EE | SCTLR_EOE | SCTLR_WXN | SCTLR_UMA | \
    SCTLR_ITD | SCTLR_THEE | SCTLR_CP15BEN | SCTLR_SA0 | SCTLR_SA | SCTLR_C | SCTLR_A)

start_mmu:
	dsb	sy

	msr	ttbr0_el1, x27
	msr	ttbr1_el1, x26
	isb

	msr	mdscr_el1, xzr

	/* Invalidate the TLB */
	tlbi	vmalle1is

#define	MEM_ATTRS		\
	   (MAIR(0x00, 0) |	\
	    MAIR(0x44, 1) |	\
	    MAIR(0xff, 2))
	ldr	x2, =(MEM_ATTRS)
	msr	mair_el1, x2

	/* Setup TCR */
	ldr	x2, =(TCR_TxSZ(63 - VIRT_BITS) | TCR_ASID_16 | TCR_IPS_40BIT | \
	    TCR_TG1_4K)
	msr	tcr_el1, x2

	/* Setup the sctlr */
	ldr	x2, =(SCTLR_SET_BITS)
	ldr	x3, =(SCTLR_CLEAR_BITS)
	mrs	x1, sctlr_el1
	bic	x1, x1, x3	/* Clear the required bits */
	orr	x1, x1, x2	/* Set the required bits */
	msr	sctlr_el1, x1
	isb

	ret

