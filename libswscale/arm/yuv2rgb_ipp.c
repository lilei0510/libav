/* 
 * yuv2rgb_ipp.c, Software YUV to RGB coverter using Intel IPP library
 *
 *  Copyright (C) 2006, David Bateman <dbateman@free.fr>
 *  All Rights Reserved.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with GNU Make; see the file COPYING.  If not, write to
 *  the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

#include <inttypes.h>
#include <stdlib.h>
#include <assert.h>

#include "libswscale/swscale_internal.h"
#include <ipp.h>
#define USE_18BPP_IPP_YUV2RGB
#ifdef USE_18BPP_IPP_YUV2RGB
/* This code is too slow relative to the C version, probably due to caching */
/* problems. Converting line by line (or in blocks) doesn't seem to help */

SwsFunc ff_yuv2rgb_init_ipp(SwsContext *c);

static uint32_t *ipp_r;
static uint32_t *ipp_g;
static uint32_t *ipp_b;

static av_always_inline int ipp_YUV2RGB_18(SwsContext *c, const uint8_t* src[], int srcStride[], int srcSliceY, int srcSliceH, uint8_t* dst[], int dstStride[])
{
	uint32_t ui32[1];
	uint8_t *ui8 = (uint8_t *)ui32;
	int Width = c->dstW;
	int j,y;
	IppiSize Sz = {Width, srcSliceH};

	if(c->srcFormat == PIX_FMT_YUV422P)
		ippiYUV422ToRGB_8u_P3C3R(src, srcStride, dst[0] + srcSliceY*dstStride[0], dstStride[0], Sz);
	else
		ippiYUV420ToRGB_8u_P3C3R(src, srcStride, dst[0] + srcSliceY*dstStride[0], dstStride[0], Sz);

	for (y=0;y<srcSliceH;y++){
		uint8_t *src_1= (uint8_t*)(dst[0] + (srcSliceY + y)*dstStride[0]);
		uint8_t *dst_1= src_1;
		for (j=0;j<Width;j++) {
			*ui32 = ipp_r[*src_1++];
			*ui32 += ipp_g[*src_1++];
			*ui32 += ipp_b[*src_1++];
			*dst_1++ = ui8[0];
			*dst_1++ = ui8[1];
			*dst_1++ = ui8[2];
		}
	}
	return srcSliceH;
}
#endif

static av_always_inline int ipp_YUV2RGB_16(SwsContext *c, const uint8_t* src[], int srcStride[], int srcSliceY, int srcSliceH, uint8_t* dst[], int dstStride[])
{
	IppiSize Sz = {c->dstW, srcSliceH};

	if(c->srcFormat == PIX_FMT_YUV422P){
		srcStride[1] *= 2;
		srcStride[2] *= 2;
	}
	ippiYUV420ToRGB565_8u16u_P3C3R(src, srcStride, (uint16_t *)(dst[0]+srcSliceY*dstStride[0]), dstStride[0], Sz);
	return srcSliceH;
}

static av_always_inline int ipp_YUV2BGR_16(SwsContext *c, const uint8_t* src[], int srcStride[], int srcSliceY, int srcSliceH, uint8_t* dst[], int dstStride[])
{
	IppiSize Sz = {c->dstW, srcSliceH};

	if(c->srcFormat == PIX_FMT_YUV422P){
		srcStride[1] *= 2;
		srcStride[2] *= 2;
	}   
	ippiYUV420ToBGR565_8u16u_P3C3R(src, srcStride, (uint16_t *)(dst[0]+srcSliceY*dstStride[0]), dstStride[0], Sz);
	return srcSliceH;
}

static av_always_inline int ipp_YUV2RGB_15(SwsContext *c, const uint8_t* src[], int srcStride[], int srcSliceY, int srcSliceH, uint8_t* dst[], int dstStride[])
{
	IppiSize Sz = {c->dstW, srcSliceH};

	if(c->srcFormat == PIX_FMT_YUV422P){
		srcStride[1] *= 2;
		srcStride[2] *= 2;
	} 
	ippiYUV420ToRGB555_8u16u_P3C3R(src, srcStride, (uint16_t *)(dst[0]+srcSliceY*dstStride[0]), dstStride[0], Sz);
	return srcSliceH;
}

static av_always_inline int ipp_YUV2BGR_15(SwsContext *c, const uint8_t* src[], int srcStride[], int srcSliceY, int srcSliceH, uint8_t* dst[], int dstStride[])
{
	IppiSize Sz = {c->dstW, srcSliceH};

	if(c->srcFormat == PIX_FMT_YUV422P){
		srcStride[1] *= 2;
		srcStride[2] *= 2;
	}
	ippiYUV420ToBGR555_8u16u_P3C3R(src, srcStride, (uint16_t *)(dst[0]+srcSliceY*dstStride[0]), dstStride[0], Sz);
	return srcSliceH;
}


SwsFunc ff_yuv2rgb_init_ipp(SwsContext *c)
{
	int i, isRgb = 0;
  
	switch(c->dstFormat){
#ifdef USE_18BPP_IPP_YUV2RGB
#ifdef malloc
#undef malloc
#endif
	case PIX_FMT_RGB19:
	case PIX_FMT_RGB18:
	  isRgb = 1;
	case PIX_FMT_BGR19:
	case PIX_FMT_BGR18:
 	  ipp_r = (uint32_t *) malloc (256 * sizeof(uint32_t));
	  for (i=0; i < 256; i++)
	    ipp_r[i] = (i >> 2) << (isRgb ? 0 : 12);
	  ipp_g = (uint32_t *) malloc (256 * sizeof(uint32_t));
	  for (i=0; i < 256; i++)
	    ipp_g[i] = (i >> 2) << 6;
	  ipp_b = (uint32_t *) malloc (256 * sizeof(uint32_t));
	  for (i=0; i < 256; i++)
	    ipp_b[i] = (i >> 2) << (isRgb ? 12 : 0);
	  return ipp_YUV2RGB_18;
#endif
	case PIX_FMT_RGB565: return ipp_YUV2RGB_16;
	case PIX_FMT_BGR565: return ipp_YUV2BGR_16;
	case PIX_FMT_RGB555: return ipp_YUV2RGB_15;
	case PIX_FMT_BGR555: return ipp_YUV2BGR_15;
	default: return NULL;
	}
}

