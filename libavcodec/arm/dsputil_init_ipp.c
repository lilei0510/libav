/*
 * Copyright (c) 2011 Wang Bin <wbsecg1@gmail.com>
 * For IPP 5
 *
 *//*
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include "libavcodec/dsputil.h"
#include "dsputil_arm.h"
#include <ipp.h>

void ff_add_pixels_clamped_arm(const DCTELEM *block, uint8_t *dest, int line_size);
void add_pixels_clamped_iwmmxt(const DCTELEM *block, uint8_t *pixels, int line_size);
void ff_dsputil_init_ipp(DSPContext* c, AVCodecContext *avctx);

static av_always_inline void ff_simple_idct_ipp(DCTELEM *block)
{
#ifdef HAVE_IWMMXT
    ippiDCT8x8Inv_Video_16s_C1I(block);
#else
    ippiDCT8x8Inv_16s_C1I(block);
#endif
}

static av_always_inline void ff_simple_idct_put_ipp(uint8_t *dest, int line_size, DCTELEM *block)
{
#ifdef HAVE_IWMMXT
	ippiDCT8x8Inv_Video_16s8u_C1R(block, dest, line_size);
#else
    ippiDCT8x8Inv_16s8u_C1R(block, dest, line_size);
#endif
}

static av_always_inline void ff_simple_idct_add_ipp(uint8_t *dest, int line_size, DCTELEM *block)
{
    ippiDCT8x8Inv_Video_16s_C1I(block);
#if HAVE_IWMMXT
    add_pixels_clamped_iwmmxt(block, dest, line_size);
#else
    ff_add_pixels_clamped_arm(block, dest, line_size);
#endif
}

void ff_dsputil_init_ipp(DSPContext* c, AVCodecContext *avctx)
{
    if (!avctx->lowres && (avctx->idct_algo == FF_IDCT_AUTO ||
                           avctx->idct_algo == FF_IDCT_SIMPLEARMV5TE)) {
        c->idct_put              = ff_simple_idct_put_ipp;
        c->idct_add              = ff_simple_idct_add_ipp;
        c->idct                  = ff_simple_idct_ipp;
        c->idct_permutation_type = FF_NO_IDCT_PERM;
    }
}

