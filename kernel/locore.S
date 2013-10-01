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
	/* TODO: Implement */
	bl	start_mmu

	ldr	x29, =0x88000000
	mov	sp, x29

	b	start

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
	/* TODO: If we need them */
#if 0
	adr	x2, hyp_vectors
	msr	vbar_el2, x2
#endif

	mov	x2, #(PSR_F | PSR_I | PSR_A | PSR_D | PSR_M_EL1h)
	msr	spsr_el2, x2
	msr	elr_el2, x30

	eret

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
 * This builds 2 page tables, the identity map and the kernel virtual map.
 * It relys on:
 *  We were loaded to an address that is on a 2MiB boundary
 *  All the memory must not cross a 1GiB boundaty
 *  x28 contains the physical address we were loaded from
 *  There are at least 5 pages before that address for the page tables
 *   The pages used are:
 *    - The kernel L1 table (TTBR0)
 *    -  The PA = VA L2 table
 *    - The FDT L1 table (TTBR1)            (not yet)
 *    -  The PA != VA L2 table to jump into (not yet)
 *    -  The FDT L2 table                   (not yet)
 */
create_pagetables:
	/* Save the Link register */
	mov	x5, x30

	ldr	x15, =(PAGE_SIZE * 5)
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
	mov	x6, x27		/* The L1 table */
	add	x7, x6, x15	/* The l2 table */
	mov	x8, x27		/* VA start (== PA start) */
	mov	x9, x27		/* PA start */
	add	x10, x9, x15	/* PA end TODO: Get the real end */
	
	bl	build_pagetable

	/* Restore the Link register */
	mov	x30, x5
	ret

/*
 * Builds a page table
 *  x6 = L1 table
 *  x7 = L2 table
 *  x8 = VA start
 *  x9 = PA start (trashed)
 *  x10 = PA end  (trashed)
 *  x11, x12 and x13 are trashed
 */
build_pagetable:
	/*
	 * Build the L1 table entry.
	 */
	/* Find the table index */
	lsr	x11, x8, #L1_ADDR_SHIFT
	and	x11, x11, #L1_ADDR_MASK
	/* Build the L1 entry to an L2 table */
	orr	x12, x7, #L1_TABLE
	/* Store the entry */
	str	x12, [x6, x11, lsl #3]

	/*
	 * Build the L2 table
	 */
	/* Find the table index */
	lsr	x11, x8, #L2_SHIFT
	and	x11, x11, #(1 << (47 - 21) - 1)
	ldr	x13, =L2_BLOCK
	/* Build the L2 block entry */
	orr	x12, x13, x11, lsl #L2_SHIFT
	and	x11, x11, #(512 - 1)
	str	x12, [x7, x11, lsl #3]
	/* TODO: Move to the next address */

	ret

#define	MAIR(attr, idx) ((attr) << ((idx) * 8))

#define	VIRT_BITS	39

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
	msr	ttbr1_el1, x27
	isb

	msr	mdscr_el1, xzr

	/* Invalidate the TLB */
	tlbi	vmalle1is

	ldr	x2, =MAIR(0x44, 0)
	msr	mair_el1, x2

	/* Setup TCR */
	ldr	x2, =(TCR_TxSZ(VIRT_BITS) | TCR_ASID_16 | TCR_IPS_40BIT | \
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

