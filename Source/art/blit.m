/*
   Copyright (C) 2002 Free Software Foundation, Inc.

   Author:  Alexander Malmberg <alexander@malmberg.org>

   This file is part of GNUstep.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

/*
This file includes itself. Many times. You have been warned.
*/

#ifndef FORMAT_INSTANCE

#include <math.h>
#include <string.h>

#include <Foundation/NSDebug.h>

#include "x11/XGServer.h"

#include "blit.h"

#endif


/*
TODO: rounding of alpha is wrong in many places, ie. an alpha of 255 is
treated as an alpha of 255/256 instead of 255/255. The
  if (alpha>127) alpha++;
hacks should take care of this with as much accuracy as we can get.
still need to fix all the remaining spots

2002-08-06: boundary cases should be correct now in most places, although
rounding is way off (but not more than 1, hopefully) for near-boundary
cases. at least pure black stays pure black and pure white stays pure white

TODO: (optional?) proper gamma handling?


TODO: more cpp magic to reduce the amount of code?
*/


/*
First attempt at gamma correction. Only used in text rendering (blit_*),
but that's where it's needed the most. The gamma adjustment is a large
hack, but the results are good.
*/
static unsigned char gamma_table[256],inv_gamma_table[256];


#define NPRE(r, pre) pre##_##r



#ifdef FORMAT_INSTANCE

/*
Define the different blitting functions. This is the important part when
the file includes itself. Each blitter is defined once for each format
using the different helper macros (or specially optimized functions in
some cases).
*/

#define M2PRE(a, b) NPRE(a, b)
#define MPRE(r) M2PRE(r, FORMAT_INSTANCE)


/* TODO: these need versions for destination alpha */

static void MPRE(blit_alpha_opaque) (unsigned char *adst,
	const unsigned char *asrc,
	unsigned char r, unsigned char g, unsigned char b, int num)
{
  const unsigned char *src = asrc;
  BLEND_TYPE *dst = (BLEND_TYPE *)adst;
  int nr, ng, nb, a;

  for (; num; num--, src++)
    {
      a = *src;
      if (!a)
	{
	  BLEND_INC(dst)
	  continue;
	}

      BLEND_READ(dst, nr, ng, nb)
      nr = inv_gamma_table[nr];
      ng = inv_gamma_table[ng];
      nb = inv_gamma_table[nb];
      nr = (r * a + nr * (255 - a) + 0xff) >> 8;
      ng = (g * a + ng * (255 - a) + 0xff) >> 8;
      nb = (b * a + nb * (255 - a) + 0xff) >> 8;
      nr = gamma_table[nr];
      ng = gamma_table[ng];
      nb = gamma_table[nb];
      BLEND_WRITE(dst, nr, ng, nb)
      BLEND_INC(dst)
    }
}

static void MPRE(blit_mono_opaque) (unsigned char *adst,
	const unsigned char *src, int src_ofs,
	unsigned char r, unsigned char g, unsigned char b,
	int num)
{
  COPY_TYPE *dst = (COPY_TYPE *)adst;
  COPY_TYPE_PIXEL(v)
  int i;
  unsigned char s;

  COPY_ASSEMBLE_PIXEL(v, r, g, b)

  s = *src++;
  i = src_ofs;
  while (src_ofs--) s <<= 1;

  for (; num; num--)
    {
      if (s&0x80)
	{
	  COPY_WRITE(dst, v)
	}
      COPY_INC(dst)
      i++;
      if (i == 8)
	{
	  s = *src++;
	  i = 0;
	}
      else
	s <<= 1;
    }
}

static void MPRE(blit_alpha) (unsigned char *adst, const unsigned char *asrc,
	unsigned char r, unsigned char g, unsigned char b, unsigned char alpha,
	int num)
{
  const unsigned char *src = asrc;
  BLEND_TYPE *dst = (BLEND_TYPE *)adst;
  int a, nr, ng, nb;

  if (alpha>127) alpha++;

  for (; num; num--, src++)
    {
      a = *src;
      if (!a)
	{
	  BLEND_INC(dst)
	  continue;
	}
      a *= alpha;
      BLEND_READ(dst, nr, ng, nb)
      nr = (r * a + nr * (65280 - a) + 0xff00) >> 16;
      ng = (g * a + ng * (65280 - a) + 0xff00) >> 16;
      nb = (b * a + nb * (65280 - a) + 0xff00) >> 16;
      BLEND_WRITE(dst, nr, ng, nb)
      BLEND_INC(dst)
    }
}

static void MPRE(blit_mono) (unsigned char *adst,
	const unsigned char *src, int src_ofs,
	unsigned char r, unsigned char g, unsigned char b, unsigned char alpha,
	int num)
{
  BLEND_TYPE *dst = (BLEND_TYPE *)adst;
  int i, nr, ng, nb;
  unsigned char s;
  int a;

  a = alpha;
  if (a>127) a++;

  s = *src++;
  i = src_ofs;
  while (src_ofs--) s <<= 1;

  for (; num; num--)
    {
      if (s&0x80)
	{
	  BLEND_READ(dst, nr, ng, nb)
	  nr = (r * a + nr * (255 - a) + 0xff) >> 8;
	  ng = (g * a + ng * (255 - a) + 0xff) >> 8;
	  nb = (b * a + nb * (255 - a) + 0xff) >> 8;
	  BLEND_WRITE(dst, nr, ng, nb)
	  BLEND_INC(dst)
	    }
      else
	{
	  BLEND_INC(dst)
	}
      i++;
      if (i == 8)
	{
	  s = *src++;
	  i = 0;
	}
      else
	s <<= 1;
    }
}


static void MPRE(blit_subpixel) (unsigned char *adst, const unsigned char *asrc,
	unsigned char r, unsigned char g, unsigned char b, unsigned char a,
	int num)
{
  const unsigned char *src = asrc;
  BLEND_TYPE *dst = (BLEND_TYPE *)adst;
  unsigned int nr, ng, nb;
  unsigned int ar, ag, ab;
  int alpha = a;

  if (alpha>127) alpha++;

  for (; num; num--)
    {
      ar = *src++;
      ag = *src++;
      ab = *src++;

      BLEND_READ(dst, nr, ng, nb)

      nr = inv_gamma_table[nr];
      ng = inv_gamma_table[ng];
      nb = inv_gamma_table[nb];

      ar *= alpha;
      ag *= alpha;
      ab *= alpha;

      nr = (r * ar + nr * (65280 - ar) + 0xff00) >> 16;
      ng = (g * ag + ng * (65280 - ag) + 0xff00) >> 16;
      nb = (b * ab + nb * (65280 - ab) + 0xff00) >> 16;

      nr = gamma_table[nr];
      ng = gamma_table[ng];
      nb = gamma_table[nb];

      BLEND_WRITE(dst, nr, ng, nb)
      BLEND_INC(dst)
    }
}


static void MPRE(run_opaque) (render_run_t *ri, int num)
{
#if FORMAT_HOW == DI_16_B5G5R5A1 || FORMAT_HOW == DI_16_B5G6R5
  unsigned int v;
  unsigned short *dst = (unsigned short *)ri->dst;

  COPY_ASSEMBLE_PIXEL(v, ri->r, ri->g, ri->b)
  v = v + (v << 16);
  if (((int)dst&2) && num)
    {
      *dst++ = v;
      num--;
    }
  while (num >= 2)
    {
      *((unsigned int *)dst) = v;
      dst += 2;
      num -= 2;
    }
  if (num)
    *dst = v;
#else
  COPY_TYPE *dst = (COPY_TYPE *)ri->dst;
  COPY_TYPE_PIXEL(v)

#if FORMAT_HOW == DI_32_RGBA || FORMAT_HOW == DI_32_BGRA || \
    FORMAT_HOW == DI_32_ARGB || FORMAT_HOW == DI_32_ABGR
  if (ri->r == ri->g && ri->r == ri->b)
    {
      num *= 4;
      memset(dst, ri->r, num);
      return;
    }
#endif

  COPY_ASSEMBLE_PIXEL(v, ri->r, ri->g, ri->b)
  for (; num; num--)
    {
      COPY_WRITE(dst, v)
      COPY_INC(dst)
    }
#endif
}

static void MPRE(run_alpha) (render_run_t *ri, int num)
{
  BLEND_TYPE *dst = (BLEND_TYPE *)ri->dst;
  int nr, ng, nb;
  int r, g, b, a;
  a = ri->a;
  r = ri->r * a;
  g = ri->g * a;
  b = ri->b * a;
  a = 255 - a;
  for (; num; num--)
    {
      BLEND_READ(dst, nr, ng, nb)
      nr = (r + nr * a + 0xff) >> 8;
      ng = (g + ng * a + 0xff) >> 8;
      nb = (b + nb * a + 0xff) >> 8;
      BLEND_WRITE(dst, nr, ng, nb)
      BLEND_INC(dst)
    }
}


static void MPRE(run_alpha_a) (render_run_t *ri, int num)
{
  int nr, ng, nb, na;
  int sr, sg, sb, a;
  BLEND_TYPE *dst = (BLEND_TYPE *)ri->dst;
#ifndef INLINE_ALPHA
  unsigned char *dst_alpha = ri->dsta;
#endif

  a = ri->a;
  sr = ri->r * a;
  sg = ri->g * a;
  sb = ri->b * a;
  a = 255 - a;

  for (; num; num--)
    {
      BLEND_READ_ALPHA(dst, dst_alpha, nr, ng, nb, na)
      nr = (sr + nr * a + 0xff) >> 8;
      ng = (sg + ng * a + 0xff) >> 8;
      nb = (sb + nb * a + 0xff) >> 8;
      na = (na * a + 0xffff - (a << 8)) >> 8;
      BLEND_WRITE_ALPHA(dst, dst_alpha, nr, ng, nb, na)
      ALPHA_INC(dst, dst_alpha)
    }
}

static void MPRE(run_opaque_a) (render_run_t *ri, int num)
{
  COPY_TYPE *dst = (COPY_TYPE *)ri->dst;
  COPY_TYPE_PIXEL(v)
  int n;

#ifdef INLINE_ALPHA
  COPY_ASSEMBLE_PIXEL_ALPHA(v, ri->r, ri->g, ri->b, 0xff)
#else
  COPY_ASSEMBLE_PIXEL(v, ri->r, ri->g, ri->b)
#endif
  for (n = num; n; n--)
    {
      COPY_WRITE(dst, v)
      COPY_INC(dst)
    }
#ifndef INLINE_ALPHA
  memset(ri->dsta, 0xff, num);
#endif
}


/* 1 : 1 - srca */
static void MPRE(sover_aa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *src_alpha = c->srca,
    *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, sa, dr, dg, db, da;

  for (; num; num--)
    {
      ALPHA_READ(s, src_alpha, sa)
      if (!sa)
	{
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (sa == 255)
	{
	  BLEND_READ(s, sr, sg, sb)
	  BLEND_WRITE_ALPHA(d, dst_alpha, sr, sg, sb, 255)
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}

      BLEND_READ(s, sr, sg, sb)
      BLEND_READ_ALPHA(d, dst_alpha, dr, dg, db, da)

      da = sa + ((da * (255 - sa) + 0xff) >> 8);
      sa = 255 - sa;
      dr = sr + ((dr * sa + 0xff) >> 8);
      dg = sg + ((dg * sa + 0xff) >> 8);
      db = sb + ((db * sa + 0xff) >> 8);

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, da)

      ALPHA_INC(s, src_alpha)
      ALPHA_INC(d, dst_alpha)
    }
}

static void MPRE(sover_ao) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *src_alpha = c->srca;
#endif
  int sr, sg, sb, sa, dr, dg, db;

  for (; num; num--)
    {
      ALPHA_READ(s, src_alpha, sa)
      if (!sa)
	{
	  ALPHA_INC(s, src_alpha)
	  BLEND_INC(d)
	  continue;
	}
      if (sa == 255)
	{
	  BLEND_READ(s, sr, sg, sb)
	  BLEND_WRITE(d, sr, sg, sb)
	  ALPHA_INC(s, src_alpha)
	  BLEND_INC(d)
	  continue;
	}

      BLEND_READ(s, sr, sg, sb)
      BLEND_READ(d, dr, dg, db)

      sa = 255 - sa;
      dr = sr + ((dr * sa + 0xff) >> 8);
      dg = sg + ((dg * sa + 0xff) >> 8);
      db = sb + ((db * sa + 0xff) >> 8);

      BLEND_WRITE(d, dr, dg, db)

      ALPHA_INC(s, src_alpha)
      BLEND_INC(d)
    }
}

/* dsta : 0 */
static void MPRE(sin_aa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *src_alpha = c->srca,
    *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, sa, dr, dg, db, da;

  for (; num; num--)
    {
      ALPHA_READ(d, dst_alpha, da)
      if (!da)
	{
	  BLEND_WRITE_ALPHA(d, dst_alpha, 0, 0, 0, 0)
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (da == 255)
	{
	  BLEND_READ_ALPHA(s, src_alpha, sr, sg, sb, sa)
	  BLEND_WRITE_ALPHA(d, dst_alpha, sr, sg, sb, sa)
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}

      BLEND_READ_ALPHA(s, src_alpha, sr, sg, sb, sa)

      dr = (sr * da + 0xff) >> 8;
      dg = (sg * da + 0xff) >> 8;
      db = (sb * da + 0xff) >> 8;
      da = (sa * da + 0xff) >> 8;

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, da)

      ALPHA_INC(s, src_alpha)
      ALPHA_INC(d, dst_alpha)
    }
}

static void MPRE(sin_oa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, dr, dg, db, da;

  for (; num; num--)
    {
      ALPHA_READ(d, dst_alpha, da)
      if (!da)
	{
	  BLEND_WRITE_ALPHA(d, dst_alpha, 0, 0, 0, 0)
	  BLEND_INC(s)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (da == 255)
	{
	  BLEND_READ(s, sr, sg, sb)
	  BLEND_WRITE_ALPHA(d, dst_alpha, sr, sg, sb, 255)
	  BLEND_INC(s)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}

      BLEND_READ(s, sr, sg, sb)

      dr = (sr * da + 0xff) >> 8;
      dg = (sg * da + 0xff) >> 8;
      db = (sb * da + 0xff) >> 8;

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, da)

      BLEND_INC(s)
      ALPHA_INC(d, dst_alpha)
    }
}

/* 1 - dsta : 0 */
static void MPRE(sout_aa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *src_alpha = c->srca,
    *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, sa, dr, dg, db, da;

  for (; num; num--)
    {
      ALPHA_READ(d, dst_alpha, da)
      da = 255 - da;
      if (!da)
	{
	  BLEND_WRITE_ALPHA(d, dst_alpha, 0, 0, 0, 0)
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (da == 255)
	{
	  BLEND_READ_ALPHA(s, src_alpha, sr, sg, sb, sa)
	  BLEND_WRITE_ALPHA(d, dst_alpha, sr, sg, sb, sa)
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}

      BLEND_READ_ALPHA(s, src_alpha, sr, sg, sb, sa)

      dr = (sr * da + 0xff) >> 8;
      dg = (sg * da + 0xff) >> 8;
      db = (sb * da + 0xff) >> 8;
      da = (sa * da + 0xff) >> 8;

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, da)

      ALPHA_INC(s, src_alpha)
      ALPHA_INC(d, dst_alpha)
    }
}

static void MPRE(sout_oa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, dr, dg, db, da;

  for (; num; num--)
    {
      ALPHA_READ(d, dst_alpha, da)
      da = 255 - da;
      if (!da)
	{
	  BLEND_WRITE_ALPHA(d, dst_alpha, 0, 0, 0, 0)
	  BLEND_INC(s)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (da == 255)
	{
	  BLEND_READ(s, sr, sg, sb)
	  BLEND_WRITE_ALPHA(d, dst_alpha, sr, sg, sb, 255)
	  BLEND_INC(s)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}

      BLEND_READ(s, sr, sg, sb)

      dr = (sr * da + 0x80) >> 8;
      dg = (sg * da + 0x80) >> 8;
      db = (sb * da + 0x80) >> 8;

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, da)

      BLEND_INC(s)
      ALPHA_INC(d, dst_alpha)
    }
}

/* dsta : 1 - srca */

/*

0 0   0 1  noop
1 0   0 0  clear, noop
0 1   1 1  noop
1 1   1 0  copy

*/

static void MPRE(satop_aa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *src_alpha = c->srca,
    *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, sa, dr, dg, db, da;

  for (; num; num--)
    {
      ALPHA_READ(d, dst_alpha, da)
      ALPHA_READ(s, src_alpha, sa)
      if (!da || (da == 255 && !sa))
	{
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (da == 255 && sa == 255)
	{
	  BLEND_READ_ALPHA(s, src_alpha, sr, sg, sb, sa)
	  BLEND_WRITE_ALPHA(d, dst_alpha, sr, sg, sb, sa)
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}

      BLEND_READ(s, sr, sg, sb)
      BLEND_READ(d, dr, dg, db)

      sa = 255 - sa;

      dr = (sr * da + dr * sa + 0xff) >> 8;
      dg = (sg * da + dg * sa + 0xff) >> 8;
      db = (sb * da + db * sa + 0xff) >> 8;
      da = ((255 - sa) * da + da * sa + 0xff) >> 8;

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, da)

      ALPHA_INC(s, src_alpha)
      ALPHA_INC(d, dst_alpha)
    }
}

/* 1 - dsta : 1 */
static void MPRE(dover_aa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *src_alpha = c->srca,
    *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, sa, dr, dg, db, da;

  for (; num; num--)
    {
      ALPHA_READ(d, dst_alpha, da)
      if (da == 255)
	{
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (!da)
	{
	  BLEND_READ_ALPHA(s, src_alpha, sr, sg, sb, sa)
	  BLEND_WRITE_ALPHA(d, dst_alpha, sr, sg, sb, sa)
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}

      BLEND_READ_ALPHA(s, src_alpha, sr, sg, sb, sa)
      BLEND_READ(d, dr, dg, db)

      sa = da + ((sa * (255 - da) + 0x80) >> 8);
      da = 255 - da;
      dr = dr + ((sr * da + 0x80) >> 8);
      dg = dg + ((sg * da + 0x80) >> 8);
      db = db + ((sb * da + 0x80) >> 8);

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, sa)

      ALPHA_INC(s, src_alpha)
      ALPHA_INC(d, dst_alpha)
    }
}

static void MPRE(dover_oa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, dr, dg, db, da;

  for (; num; num--)
    {
      ALPHA_READ(d, dst_alpha, da)
      if (da == 255)
	{
	  BLEND_INC(s)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (!da)
	{
	  BLEND_READ(s, sr, sg, sb)
	  BLEND_WRITE_ALPHA(d, dst_alpha, sr, sg, sb, 255)
	  BLEND_INC(s)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}

      BLEND_READ(s, sr, sg, sb)
      BLEND_READ(d, dr, dg, db)

      da = 255 - da;
      dr = dr + ((sr * da + 0x80) >> 8);
      dg = dg + ((sg * da + 0x80) >> 8);
      db = db + ((sb * da + 0x80) >> 8);

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, 255)

      BLEND_INC(s)
      ALPHA_INC(d, dst_alpha)
    }
}

/* 0 : srca */
static void MPRE(din_aa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *src_alpha = c->srca,
    *dst_alpha = c->dsta;
#endif
  int sa, dr, dg, db, da;

  for (; num; num--)
    {
      ALPHA_READ(s, src_alpha, sa)
      if (!sa)
	{
	  BLEND_WRITE_ALPHA(d, dst_alpha, 0, 0, 0, 0)
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (sa == 255)
	{
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}

      BLEND_READ_ALPHA(d, dst_alpha, dr, dg, db, da)

      dr = (dr * sa + 0x80) >> 8;
      dg = (dg * sa + 0x80) >> 8;
      db = (db * sa + 0x80) >> 8;
      da = (da * sa + 0x80) >> 8;

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, da)

      ALPHA_INC(s, src_alpha)
      ALPHA_INC(d, dst_alpha)
    }
}

/* 0 : 1 - srca */
static void MPRE(dout_aa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *src_alpha = c->srca,
    *dst_alpha = c->dsta;
#endif
  int sa, dr, dg, db, da;

  for (; num; num--)
    {
      ALPHA_READ(s, src_alpha, sa)
      sa = 255 - sa;
      if (!sa)
	{
	  BLEND_WRITE_ALPHA(d, dst_alpha, 0, 0, 0, 0)
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (sa == 255)
	{
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	    continue;
	}

      BLEND_READ_ALPHA(d, dst_alpha, dr, dg, db, da)

      dr = (dr * sa + 0x80) >> 8;
      dg = (dg * sa + 0x80) >> 8;
      db = (db * sa + 0x80) >> 8;
      da = (da * sa + 0x80) >> 8;

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, da)

      ALPHA_INC(s, src_alpha)
      ALPHA_INC(d, dst_alpha)
    }
}

/* 1 - dstA : srcA */

/*

0 0   1 0 clear, noop
1 0   1 1 copy
0 1   0 0 clear
1 1   0 1 noop

*/

static void MPRE(datop_aa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *src_alpha = c->srca,
    *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, sa, dr, dg, db, da;

  for (; num; num--)
    {
      ALPHA_READ(d, dst_alpha, da)
      ALPHA_READ(s, src_alpha, sa)
      if ((!da && !sa) || (da == 255 && sa == 255))
	{
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (da == 255 && !sa)
	{
	  BLEND_WRITE_ALPHA(d, dst_alpha, 0, 0, 0, 0)
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (sa == 255 && !da)
	{
	  BLEND_READ_ALPHA(s, src_alpha, sr, sg, sb, sa)
	  BLEND_WRITE_ALPHA(d, dst_alpha, sr, sg, sb, sa)
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}

      BLEND_READ(s, sr, sg, sb)
      BLEND_READ(d, dr, dg, db)

      da = 255 - da;

      dr = (dr * sa + sr * da + 0x80) >> 8;
      dg = (dg * sa + sg * da + 0x80) >> 8;
      db = (db * sa + sb * da + 0x80) >> 8;
      da = ((255 - da) * sa + sa * da + 0x80) >> 8;

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, da)

      ALPHA_INC(s, src_alpha)
      ALPHA_INC(d, dst_alpha)
    }
}

/* 1 - dsta : 1 - srca */

/*

0 0  1 1 clear, noop
1 0  0 1 noop
0 1  1 0 copy
1 1  0 0 clear

*/

static void MPRE(xor_aa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *src_alpha = c->srca,
    *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, sa, dr, dg, db, da;

  for (; num; num--)
    {
      ALPHA_READ(s, src_alpha, sa)
      ALPHA_READ(d, dst_alpha, da)
      if (!sa && (da == 255 || !da))
	{
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (sa == 255 && !da)
	{
	  BLEND_READ(s, sr, sg, sb)
	  BLEND_WRITE_ALPHA(d, dst_alpha, sr, sg, sb, sa)
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}
      if (da == 255 && sa == 255)
	{
	  BLEND_WRITE_ALPHA(d, dst_alpha, 0, 0, 0, 0)
	  ALPHA_INC(s, src_alpha)
	  ALPHA_INC(d, dst_alpha)
	  continue;
	}

      BLEND_READ(s, sr, sg, sb)
      BLEND_READ(d, dr, dg, db)

      da = 255 - da;
      sa = 255 - sa;
      dr = ((dr * sa + sr * da + 0x80) >> 8);
      dg = ((dg * sa + sg * da + 0x80) >> 8);
      db = ((db * sa + sb * da + 0x80) >> 8);
      da = ((da * (255 - sa) + sa * (255 - da) + 0x80) >> 8);

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, da)

      ALPHA_INC(s, src_alpha)
      ALPHA_INC(d, dst_alpha)
    }
}


static void MPRE(plusl_aa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *src_alpha = c->srca,
    *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, sa, dr, dg, db, da;

  for (; num; num--)
    {
      BLEND_READ_ALPHA(s, src_alpha, sr, sg, sb, sa)
      BLEND_READ_ALPHA(d, dst_alpha, dr, dg, db, da)

      dr += sr; if (dr>255) dr = 255;
      dg += sg; if (dg>255) dg = 255;
      db += sb; if (db>255) db = 255;
      da += sa; if (da>255) da = 255;

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, da)

      ALPHA_INC(s, src_alpha)
      ALPHA_INC(d, dst_alpha)
    }
}
static void MPRE(plusl_oa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, dr, dg, db;

  for (; num; num--)
    {
      BLEND_READ(s, sr, sg, sb)
      BLEND_READ(d, dr, dg, db)

      dr += sr; if (dr>255) dr = 255;
      dg += sg; if (dg>255) dg = 255;
      db += sb; if (db>255) db = 255;

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, 0xff)

      BLEND_INC(s)
      ALPHA_INC(d, dst_alpha)
    }
}
static void MPRE(plusl_ao_oo) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
  int sr, sg, sb, dr, dg, db;

  for (; num; num--)
    {
      BLEND_READ(s, sr, sg, sb)
      BLEND_READ(d, dr, dg, db)

      dr += sr; if (dr>255) dr = 255;
      dg += sg; if (dg>255) dg = 255;
      db += sb; if (db>255) db = 255;

      BLEND_WRITE(d, dr, dg, db)

      BLEND_INC(s)
      BLEND_INC(d)
    }
}


static void MPRE(plusd_aa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *src_alpha = c->srca,
    *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, sa, dr, dg, db, da;

  for (; num; num--)
    {
      BLEND_READ_ALPHA(s, src_alpha, sr, sg, sb, sa)
      BLEND_READ_ALPHA(d, dst_alpha, dr, dg, db, da)

      dr += sr - 255; if (dr<0) dr = 0;
      dg += sg - 255; if (dg<0) dg = 0;
      db += sb - 255; if (db<0) db = 0;
      da += sa - 255; if (da<0) da = 0;

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, da)

      ALPHA_INC(s, src_alpha)
      ALPHA_INC(d, dst_alpha)
    }
}
static void MPRE(plusd_oa) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
#ifndef INLINE_ALPHA
  unsigned char *dst_alpha = c->dsta;
#endif
  int sr, sg, sb, dr, dg, db;

  for (; num; num--)
    {
      BLEND_READ(s, sr, sg, sb)
      BLEND_READ(d, dr, dg, db)

      dr += sr - 255; if (dr<0) dr = 0;
      dg += sg - 255; if (dg<0) dg = 0;
      db += sb - 255; if (db<0) db = 0;

      BLEND_WRITE_ALPHA(d, dst_alpha, dr, dg, db, 0xff)

      BLEND_INC(s)
      ALPHA_INC(d, dst_alpha)
    }
}
static void MPRE(plusd_ao_oo) (composite_run_t *c, int num)
{
  BLEND_TYPE *s = (BLEND_TYPE *)c->src, *d = (BLEND_TYPE *)c->dst;
  int sr, sg, sb, dr, dg, db;

  for (; num; num--)
    {
      BLEND_READ(s, sr, sg, sb)
      BLEND_READ(d, dr, dg, db)

      dr += sr - 255; if (dr<0) dr = 0;
      dg += sg - 255; if (dg<0) dg = 0;
      db += sb - 255; if (db<0) db = 0;

      BLEND_WRITE(d, dr, dg, db)

      BLEND_INC(s)
      BLEND_INC(d)
    }
}


#undef I_NAME
#undef BLEND_TYPE
#undef BLEND_READ
#undef BLEND_READ_ALPHA
#undef BLEND_WRITE
#undef BLEND_WRITE_ALPHA
#undef BLEND_INC
#undef ALPHA_READ
#undef ALPHA_INC
#undef COPY_TYPE
#undef COPY_TYPE_PIXEL
#undef COPY_ASSEMBLE_PIXEL
#undef COPY_ASSEMBLE_PIXEL_ALPHA
#undef COPY_WRITE
#undef COPY_INC
#undef FORMAT_HOW
#undef INLINE_ALPHA

#else


/*
For each supported pixel format we define a bunch of macros and include
ourself.
*/


/* 24-bit red green blue */
#define FORMAT_INSTANCE rgb
#define FORMAT_HOW DI_24_RGB
#warning RGB

#define BLEND_TYPE unsigned char
#define BLEND_READ(p,nr,ng,nb) nr=p[0]; ng=p[1]; nb=p[2];
#define BLEND_READ_ALPHA(p,pa,nr,ng,nb,na) nr=p[0]; ng=p[1]; nb=p[2]; na=pa[0];
#define BLEND_WRITE(p,nr,ng,nb) p[0]=nr; p[1]=ng; p[2]=nb;
#define BLEND_WRITE_ALPHA(p,pa,nr,ng,nb,na) p[0]=nr; p[1]=ng; p[2]=nb; pa[0]=na;
#define BLEND_INC(p) p+=3;

#define ALPHA_READ(s,sa,d) d=sa[0];
#define ALPHA_INC(s,sa) s+=3; sa++;

#define COPY_TYPE unsigned char
#define COPY_TYPE_PIXEL(a) unsigned char a[3];
#define COPY_ASSEMBLE_PIXEL(v,r,g,b) v[0]=r; v[1]=g; v[2]=b;
#define COPY_WRITE(dst,v) dst[0]=v[0]; dst[1]=v[1]; dst[2]=v[2];
#define COPY_INC(dst) dst+=3;

#include "blit.m"

#undef FORMAT_INSTANCE


/* 24-bit blue green red */
#define FORMAT_INSTANCE bgr
#define FORMAT_HOW DI_24_BGR
#warning BGR

#define BLEND_TYPE unsigned char
#define BLEND_READ(p,nr,ng,nb) nb=p[0]; ng=p[1]; nr=p[2];
#define BLEND_READ_ALPHA(p,pa,nr,ng,nb,na) nb=p[0]; ng=p[1]; nr=p[2]; na=pa[0];
#define BLEND_WRITE(p,nr,ng,nb) p[0]=nb; p[1]=ng; p[2]=nr;
#define BLEND_WRITE_ALPHA(p,pa,nr,ng,nb,na) p[0]=nb; p[1]=ng; p[2]=nr; pa[0]=na;
#define BLEND_INC(p) p+=3;

#define ALPHA_READ(s,sa,d) d=sa[0];
#define ALPHA_INC(s,sa) s+=3; sa++;

#define COPY_TYPE unsigned char
#define COPY_TYPE_PIXEL(a) unsigned char a[3];
#define COPY_ASSEMBLE_PIXEL(v,r,g,b) v[0]=b; v[1]=g; v[2]=r;
#define COPY_WRITE(dst,v) dst[0]=v[0]; dst[1]=v[1]; dst[2]=v[2];
#define COPY_INC(dst) dst+=3;

#include "blit.m"

#undef FORMAT_INSTANCE


/* 32-bit red green blue alpha */
#define FORMAT_INSTANCE rgba
#define FORMAT_HOW DI_32_RGBA
#warning RGBA

#define INLINE_ALPHA

#define BLEND_TYPE unsigned char
#define BLEND_READ(p,nr,ng,nb) nr=p[0]; ng=p[1]; nb=p[2];
#define BLEND_READ_ALPHA(p,pa,nr,ng,nb,na) nr=p[0]; ng=p[1]; nb=p[2]; na=p[3];
#define BLEND_WRITE(p,nr,ng,nb) p[0]=nr; p[1]=ng; p[2]=nb;
#define BLEND_WRITE_ALPHA(p,pa,nr,ng,nb,na) p[0]=nr; p[1]=ng; p[2]=nb; p[3]=na;
#define BLEND_INC(p) p+=4;

#define ALPHA_READ(s,sa,d) d=s[3];
#define ALPHA_INC(s,sa) s+=4;

#define COPY_TYPE unsigned int
#define COPY_TYPE_PIXEL(a) unsigned int a;
#if GS_WORDS_BIGENDIAN
#define COPY_ASSEMBLE_PIXEL(v,r,g,b) v=(r<<24)|(g<<16)|(b<<8);
#define COPY_ASSEMBLE_PIXEL_ALPHA(v,r,g,b,a) v=(r<<24)|(g<<16)|(b<<8)|(a);
#else
#define COPY_ASSEMBLE_PIXEL(v,r,g,b) v=(b<<16)|(g<<8)|(r<<0);
#define COPY_ASSEMBLE_PIXEL_ALPHA(v,r,g,b,a) v=(b<<16)|(g<<8)|(r<<0)|(a<<24);
#endif
#define COPY_WRITE(dst,v) dst[0]=v;
#define COPY_INC(dst) dst++;

#include "blit.m"

#undef FORMAT_INSTANCE


/* 32-bit blue green red alpha */
#define FORMAT_INSTANCE bgra
#define FORMAT_HOW DI_32_BGRA
#warning BGRA

#define INLINE_ALPHA

#define BLEND_TYPE unsigned char
#define BLEND_READ(p,nr,ng,nb) nb=p[0]; ng=p[1]; nr=p[2];
#define BLEND_READ_ALPHA(p,pa,nr,ng,nb,na) nb=p[0]; ng=p[1]; nr=p[2]; na=p[3];
#define BLEND_WRITE(p,nr,ng,nb) p[0]=nb; p[1]=ng; p[2]=nr;
#define BLEND_WRITE_ALPHA(p,pa,nr,ng,nb,na) p[0]=nb; p[1]=ng; p[2]=nr; p[3]=na;
#define BLEND_INC(p) p+=4;

#define ALPHA_READ(s,sa,d) d=s[3];
#define ALPHA_INC(s,sa) s+=4;

#define COPY_TYPE unsigned int
#define COPY_TYPE_PIXEL(a) unsigned int a;
#if GS_WORDS_BIGENDIAN
#define COPY_ASSEMBLE_PIXEL(v,r,g,b) v=(b<<24)|(g<<16)|(r<<8);
#define COPY_ASSEMBLE_PIXEL_ALPHA(v,r,g,b,a) v=(b<<24)|(g<<16)|(r<<8)|(a);
#else
#define COPY_ASSEMBLE_PIXEL(v,r,g,b) v=(r<<16)|(g<<8)|(b<<0);
#define COPY_ASSEMBLE_PIXEL_ALPHA(v,r,g,b,a) v=(r<<16)|(g<<8)|(b<<0)|(a<<24);
#endif
#define COPY_WRITE(dst,v) dst[0]=v;
#define COPY_INC(dst) dst++;

#include "blit.m"

#undef FORMAT_INSTANCE


/* 32-bit alpha red green blue */
#define FORMAT_INSTANCE argb
#define FORMAT_HOW DI_32_ARGB
#warning ARGB

#define INLINE_ALPHA

#define BLEND_TYPE unsigned char
#define BLEND_READ(p,nr,ng,nb) nr=p[1]; ng=p[2]; nb=p[3];
#define BLEND_READ_ALPHA(p,pa,nr,ng,nb,na) nr=p[1]; ng=p[2]; nb=p[3]; na=p[0];
#define BLEND_WRITE(p,nr,ng,nb) p[1]=nr; p[2]=ng; p[3]=nb;
#define BLEND_WRITE_ALPHA(p,pa,nr,ng,nb,na) p[1]=nr; p[2]=ng; p[3]=nb; p[0]=na;
#define BLEND_INC(p) p+=4;

#define ALPHA_READ(s,sa,d) d=s[0];
#define ALPHA_INC(s,sa) s+=4;

#define COPY_TYPE unsigned int
#define COPY_TYPE_PIXEL(a) unsigned int a;
#if GS_WORDS_BIGENDIAN
#define COPY_ASSEMBLE_PIXEL(v,r,g,b) v=(r<<16)|(g<<8)|(b<<0);
#define COPY_ASSEMBLE_PIXEL_ALPHA(v,r,g,b,a) v=(r<<16)|(g<<8)|(b<<0)|(a<<24);
#else
#define COPY_ASSEMBLE_PIXEL(v,r,g,b) v=(b<<24)|(g<<16)|(r<<8);
#define COPY_ASSEMBLE_PIXEL_ALPHA(v,r,g,b,a) v=(b<<24)|(g<<16)|(r<<8)|(a);
#endif
#define COPY_WRITE(dst,v) dst[0]=v;
#define COPY_INC(dst) dst++;

#include "blit.m"

#undef FORMAT_INSTANCE


/* 32-bit alpha blue green red */
#define FORMAT_INSTANCE abgr
#define FORMAT_HOW DI_32_ABGR
#warning ABGR

#define INLINE_ALPHA

#define BLEND_TYPE unsigned char
#define BLEND_READ(p,nr,ng,nb) nb=p[1]; ng=p[2]; nr=p[3];
#define BLEND_READ_ALPHA(p,pa,nr,ng,nb,na) nb=p[1]; ng=p[2]; nr=p[3]; na=p[0];
#define BLEND_WRITE(p,nr,ng,nb) p[1]=nb; p[2]=ng; p[3]=nr;
#define BLEND_WRITE_ALPHA(p,pa,nr,ng,nb,na) p[1]=nb; p[2]=ng; p[3]=nr; p[0]=na;
#define BLEND_INC(p) p+=4;

#define ALPHA_READ(s,sa,d) d=s[0];
#define ALPHA_INC(s,sa) s+=4;

#define COPY_TYPE unsigned int
#define COPY_TYPE_PIXEL(a) unsigned int a;
#if GS_WORDS_BIGENDIAN
#define COPY_ASSEMBLE_PIXEL(v,r,g,b) v=(b<<16)|(g<<8)|(r<<0);
#define COPY_ASSEMBLE_PIXEL_ALPHA(v,r,g,b,a) v=(b<<16)|(g<<8)|(r<<0)|(a<<24);
#else
#define COPY_ASSEMBLE_PIXEL(v,r,g,b) v=(r<<24)|(g<<16)|(b<<8);
#define COPY_ASSEMBLE_PIXEL_ALPHA(v,r,g,b,a) v=(r<<24)|(g<<16)|(b<<8)|(a);
#endif
#define COPY_WRITE(dst,v) dst[0]=v;
#define COPY_INC(dst) dst++;

#include "blit.m"

#undef FORMAT_INSTANCE


/* 16-bit  5 bits blue, 6 bits green, 5 bits red */
#define FORMAT_INSTANCE b5g6r5
#define FORMAT_HOW DI_16_B5G6R5
#warning B5G6R5

#define BLEND_TYPE unsigned short
#define BLEND_READ(p,nr,ng,nb) \
	{ \
		unsigned short _s=p[0]; \
		nr=(_s>>11)<<3; \
		ng=((_s>>5)<<2)&0xff; \
		nb=(_s<<3)&0xff; \
	}
#define BLEND_READ_ALPHA(p,pa,nr,ng,nb,na) \
	{ \
		unsigned short _s=p[0]; \
		nr=(_s>>11)<<3; \
		ng=((_s>>5)<<2)&0xff; \
		nb=(_s<<3)&0xff; \
		na=pa[0]; \
	}
#define BLEND_WRITE(p,nr,ng,nb) p[0]=((nr>>3)<<11)|((ng>>2)<<5)|(nb>>3);
#define BLEND_WRITE_ALPHA(p,pa,nr,ng,nb,na) p[0]=((nr>>3)<<11)|((ng>>2)<<5)|(nb>>3); pa[0]=na;
#define BLEND_INC(p) p++;

#define ALPHA_READ(s,sa,d) d=sa[0];
#define ALPHA_INC(s,sa) s++; sa++;

#define COPY_TYPE unsigned short
#define COPY_TYPE_PIXEL(a) unsigned short a;
#define COPY_ASSEMBLE_PIXEL(v,r,g,b) v=((r>>3)<<11)|((g>>2)<<5)|(b>>3);
#define COPY_WRITE(dst,v) dst[0]=v;
#define COPY_INC(dst) dst++;

#include "blit.m"
#undef FORMAT_INSTANCE


/* 16-bit  5 bits blue, 5 bits green, 5 bits red */
#define FORMAT_INSTANCE b5g5r5a1
#define FORMAT_HOW DI_16_B5G5R5A1
#warning B5G5R5A1

#define BLEND_TYPE unsigned short
#define BLEND_READ(p,nr,ng,nb) \
	{ \
		unsigned short _s=p[0]; \
		nr=(_s>>10)<<3; \
		ng=((_s>>5)<<3)&0xff; \
		nb=(_s<<3)&0xff; \
	}
#define BLEND_READ_ALPHA(p,pa,nr,ng,nb,na) \
	{ \
		unsigned short _s=p[0]; \
		nr=(_s>>10)<<3; \
		ng=((_s>>5)<<3)&0xff; \
		nb=(_s<<3)&0xff; \
		na=pa[0]; \
	}
#define BLEND_WRITE(p,nr,ng,nb) p[0]=((nr>>3)<<10)+((ng>>3)<<5)+(nb>>3);
#define BLEND_WRITE_ALPHA(p,pa,nr,ng,nb,na) p[0]=((nr>>3)<<10)+((ng>>3)<<5)+(nb>>3); pa[0]=na;
#define BLEND_INC(p) p++;

#define ALPHA_READ(s,sa,d) d=sa[0];
#define ALPHA_INC(s,sa) s++; sa++;

#define COPY_TYPE unsigned short
#define COPY_TYPE_PIXEL(a) unsigned short a;
#define COPY_ASSEMBLE_PIXEL(v,r,g,b) v=((r>>3)<<10)|((g>>3)<<5)|(b>>3);
#define COPY_WRITE(dst,v) dst[0]=v;
#define COPY_INC(dst) dst++;

#include "blit.m"
#undef FORMAT_INSTANCE

/* end of pixel formats */


static draw_info_t draw_infos[DI_NUM] = {

#define C(x) \
  NPRE(run_alpha,x), \
  NPRE(run_opaque,x), \
  NPRE(run_alpha_a,x), \
  NPRE(run_opaque_a,x), \
  NPRE(blit_alpha_opaque,x), \
  NPRE(blit_mono_opaque,x), \
  NPRE(blit_alpha,x), \
  NPRE(blit_mono,x), \
  \
  NPRE(blit_subpixel,x), \
  \
  NPRE(sover_aa,x), \
  NPRE(sover_ao,x), \
  NPRE(sin_aa,x), \
  NPRE(sin_oa,x), \
  NPRE(sout_aa,x), \
  NPRE(sout_oa,x), \
  NPRE(satop_aa,x), \
  NPRE(dover_aa,x), \
  NPRE(dover_oa,x), \
  NPRE(din_aa,x), \
  NPRE(dout_aa,x), \
  NPRE(datop_aa,x), \
  NPRE(xor_aa,x), \
  NPRE(plusl_aa,x), \
  NPRE(plusl_oa,x), \
  NPRE(plusl_ao_oo,x), \
  NPRE(plusl_ao_oo,x), \
  NPRE(plusd_aa,x), \
  NPRE(plusd_oa,x), \
  NPRE(plusd_ao_oo,x), \
  NPRE(plusd_ao_oo,x), \

/* TODO: try to implement fallback versions? possible? */
{DI_FALLBACK       ,0, 0,0,-1,/*C(fallback)*/},

{DI_16_B5_G5_R5_A1 ,2,15,0,-1,C(b5g5r5a1)},
{DI_16_B5_G6_R5    ,2,16,0,-1,C(b5g6r5)},
{DI_24_RGB         ,3,24,0,-1,C(rgb)},
{DI_24_BGR         ,3,24,0,-1,C(bgr)},
/* ARTContext.m assumes that only 32-bit modes have inline alpha. this
might eventually need to be fixed */
{DI_32_RGBA        ,4,24,1, 3,C(rgba)},
{DI_32_BGRA        ,4,24,1, 3,C(bgra)},
{DI_32_ARGB        ,4,24,1, 0,C(argb)},
{DI_32_ABGR        ,4,24,1, 0,C(abgr)},
};



static int byte_ofs_of_mask(unsigned int m)
{
  union
    {
      unsigned char b[4];
      unsigned int m;
    } tmp;

  tmp.m = m;
  if (tmp.b[0] == 0xff && !tmp.b[1] && !tmp.b[2] && !tmp.b[3])
    return 0;
  else if (tmp.b[1] == 0xff && !tmp.b[0] && !tmp.b[2] && !tmp.b[3])
    return 1;
  else if (tmp.b[2] == 0xff && !tmp.b[0] && !tmp.b[1] && !tmp.b[3])
    return 2;
  else if (tmp.b[3] == 0xff && !tmp.b[0] && !tmp.b[1] && !tmp.b[2])
    return 3;
  else
    return -1;
}


#include <Foundation/NSUserDefaults.h>

void artcontext_setup_draw_info(draw_info_t *di,
	unsigned int red_mask, unsigned int green_mask, unsigned int blue_mask,
	int bpp)
{
  int t = DI_FALLBACK;

  if (bpp == 16 && red_mask == 0xf800 && green_mask == 0x7e0 &&
      blue_mask == 0x1f)
    {
      t = DI_16_B5_G6_R5;
    }
  else if (bpp == 16 &&  red_mask == 0x7c00 && green_mask == 0x3e0 &&
	   blue_mask == 0x1f)
    {
      t = DI_16_B5_G5_R5_A1;
    }
  else if (bpp == 24 || bpp == 32)
    {
      int r, g, b;

      r = byte_ofs_of_mask(red_mask);
      g = byte_ofs_of_mask(green_mask);
      b = byte_ofs_of_mask(blue_mask);

      if (bpp == 24)
	{
	  if (r == 0 && g == 1 && b == 2)
	    t = DI_24_RGB;
	  else if (r == 2 && g == 1 && b == 0)
	    t = DI_24_BGR;
	}
      else if (bpp == 32)
	{
	  if (r == 0 && g == 1 && b == 2)
	    t = DI_32_RGBA;
	  else if (r == 2 && g == 1 && b == 0)
	    t = DI_32_BGRA;
	  else if (r == 1 && g == 2 && b == 3)
	    t = DI_32_ARGB;
	  else if (r == 3 && g == 2 && b == 1)
	    t = DI_32_ABGR;
	}
    }

  *di = draw_infos[t];
  if (!di->render_run_alpha)
    *di = draw_infos[DI_FALLBACK];
  if (di->how == DI_FALLBACK)
    {
      NSLog(@"Unrecognized color masks: %08x:%08x:%08x %i",
	    red_mask, green_mask, blue_mask, bpp);
      //		NSLog(@"Attempting to use fallback code (currently unimplemented). This will be _very_ slow!");
      NSLog(@"Please report this along with details on your pixel format "
	    @"(ie. the four numbers above). (Or better yet, implement it "
	    @"and send me a patch.)");
      exit(1);
    }

  {
    float gamma = [[NSUserDefaults standardUserDefaults]
                      floatForKey: @"back-art-text-gamma"];
    int i;
    if (!gamma)
      gamma = 1.4;

    NSDebugLLog(@"back-art",@"gamma=%g",gamma);

    gamma = 1.0 / gamma;

    for (i = 0; i < 256; i++)
      {
	gamma_table[i] = pow(i / 255.0, gamma) * 255 + .5;
	inv_gamma_table[i] = pow(i / 255.0, 1.0 / gamma) * 255 + .5;
      }
  }
}
#endif


#if 0
/* potentially interesting old implementations of stuff */

static void r5g6b5_blit_mono_opaque(
/* ... */
	/* TODO: could optimize with a two-bit check and a four-way branch
	that writes two pixels in one go */
/* ... */
}

#endif


/*

compositing:                   source opaque/dest. opaque
                               00               01               10               11
Clear   0          0         +ab, clear
Copy    1          0           copy all         +ab, copy        copy             copy

Sover   1          1 - srcA    impl             impl             copy             copy
Sin     dstA       0           impl             +ab, copy        impl             copy
Sout    1 - dstA   0           impl             clear            impl             clear
Satop   dstA       1 - srcA    impl             Sover 01         Sin 10           copy

Dover   1 - dstA   1           impl             noop             impl             noop
Din     0          srcA        impl             +ab, 00          noop             noop
Dout    0          1 - srcA    impl             +ab, 00          clear            clear
Datop   1 - dstA   srcA        impl             +ab, 00          Dover 10         noop

Xor     1 - dstA   1 - srcA    impl             +ab, 00          Sout 10          clear

PlusL                          impl             impl             impl             impl
dst=dst+src, dsta=dsta+srca

PlusD                          impl             impl             impl             impl
dst=dst+src-1, dsta=dsta+srca


compositing (source transparent) dest. opaque
                               0                1
Clear   0          0           clear            clear
Copy    1          0           clear            clear

Sover   1          1 - srcA    noop             noop
Sin     dstA       0           clear            clear
Sout    1 - dstA   0           clear            clear
Satop   dstA       1 - srcA    noop             noop

Dover   1 - dstA   1           noop             noop
Din     0          srcA        clear            clear
Dout    0          1 - srcA    noop             noop
Datop   1 - dstA   srcA        clear            clear

Xor     1 - dstA   1 - srcA    noop             noop



PlusL    dst=src+dst  , clamp to 1.0; dsta=srca+dsta, clamp to 1.0
PlisD    dst=src+dst-1, clamp to 0.0; dsta=srca+dsta, clamp to 1.0

these are incorrect:

PlusD
[PlusD does not follow the general equation. The equation is dst'=(1-dst)+(1-src).
If the result is less than 0 (black), then the result is 0.]
N/A
N/A

PlusL
[For PlusL, the addition saturates. That is, if (src+dst) > white), the result is white.]
1
1

*/

