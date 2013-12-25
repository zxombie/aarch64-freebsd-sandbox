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

#ifndef	_ARM64_INCLUDE_PTE_H_
#define	_ARM64_INCLUDE_PTE_H_

/*
 * These are for 4k granules
 */

#define	VA_BITS		47
#define	Ln_OUT_MASK(shift)	(((1 << (VA_BITS + 1 - (shift))) - 1) << (shift))

/* First-level table */
#define	L1_INVAL	0x00
#define	L1_BLOCK	0x01
#define	L1_TABLE	0x03

#define	L1_SHIFT	30
#define	L1_SIZE		(1 << L1_SHIFT)
#define	L1_MASK		(L1_SIZE - 1)

#define	L1_IDX_MASK	(512 - 1)
#define	L1_OUT_MASK	Ln_OUT_MASK(L1_SHIFT)
#define	L1_TBL_MASK	Ln_OUT_MASK(12)


/* Second-level table */
#define	L2_INVAL	0x00
#define	L2_BLOCK	0x01
#define	L2_TABLE	0x03

#define	L2_SHIFT	21
#define	L2_SIZE		(1 << L2_SHIFT)
#define	L2_MASK		(L2_SIZE - 1)

#define	L2_IDX_MASK	(512 - 1)
#define	L2_OUT_MASK	Ln_OUT_MASK(L2_SHIFT)


/* Third-level entry */
#define	L3_INVAL	0x00
#define	L3_PAGE		0x03

#endif

