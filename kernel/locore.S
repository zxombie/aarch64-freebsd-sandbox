/*-
 * Copyright (c) 2012 Andrew Turner
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
	/*bl	start_mmu*/

	ldr	x29, =0x88000000
	mov	sp, x29

	b	start

drop_to_el1:
	/* TODO: Implement */
	mrs	x1, CurrentEL
	ret

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
	sub	x7, x6, x15	/* The l2 table TODO: clean it */
	mov	x8, x27		/* VA start (== PA start) */
	mov	x9, x28		/* PA start */
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
 * x11, x12 and x13 are trashed
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
	and	x11, x11, #(512 - 1)
	ldr	x13, =L2_BLOCK
	/* Build the L2 block entry */
	orr	x12, x13, x11, lsl #L2_SHIFT
	str	x12, [x7, x11, lsl #3]
	/* TODO: Move to the next address */

	ret

