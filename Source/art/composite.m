/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>

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

#include <AppKit/NSAffineTransform.h>

#include "ARTGState.h"

#include "ARTWindowBuffer.h"
#include "blit.h"


@implementation ARTGState (composite)

/* Figure out what blit function we should use. If one or both of the
windows are known to be totally opaque, we can optimize in many ways
(see big table at the end of blit.m). Will set dst_need_alpha and blit_func
if necessary. Returns new operation, or -1 it it's a noop. */
-(int) _composite_func: (BOOL)src_opaque : (BOOL)src_transparent
	: (BOOL)dst_opaque : (BOOL *)dst_needs_alpha
	: (int)op : (void (**)(composite_run_t *c, int num))blit_func_r
{
  void (*blit_func)(composite_run_t *c, int num);

  *dst_needs_alpha = NO;
  *blit_func_r = blit_func = NULL;

  if (src_transparent) /* only happens with compositerect */
    {
      switch (op)
	{
	case NSCompositeCopy:
	case NSCompositeSourceIn:
	case NSCompositeSourceOut:
	case NSCompositeDestinationIn:
	case NSCompositeDestinationAtop:
	case NSCompositePlusDarker:
	  return NSCompositeClear;

	case NSCompositeSourceOver:
	case NSCompositeSourceAtop:
	case NSCompositeDestinationOver:
	case NSCompositeDestinationOut:
	case NSCompositeXOR:
	case NSCompositePlusLighter:
	  return -1; /* noop */
	}
    }
  else
    if (src_opaque && dst_opaque)
      { /* both source and destination are totally opaque */
	switch (op)
	  {
	  case NSCompositeSourceOver:
	  case NSCompositeSourceIn:
	  case NSCompositeSourceAtop:
	    return NSCompositeCopy;

	  case NSCompositeSourceOut:
	  case NSCompositeDestinationOut:
	  case NSCompositeXOR:
	    return NSCompositeClear;

	  case NSCompositeDestinationOver:
	  case NSCompositeDestinationIn:
	  case NSCompositeDestinationAtop:
	    return -1; /* noop */

	  case NSCompositePlusLighter:
	    blit_func = DI.composite_plusl_oo;
	    break;
	  case NSCompositePlusDarker:
	    blit_func = DI.composite_plusd_oo;
	    break;
	  }
      }
    else if (src_opaque)
      { /* source is opaque, destination has alpha */
	switch (op)
	  {
	  case NSCompositeSourceOver:
	    return NSCompositeCopy;

	  case NSCompositeSourceIn:
	  case NSCompositeSourceAtop:
	    blit_func = DI.composite_sin_oa;
	    break;

	  case NSCompositeSourceOut:
	  case NSCompositeXOR:
	    blit_func = DI.composite_sout_oa;
	    break;

	  case NSCompositeDestinationOver:
	  case NSCompositeDestinationAtop:
	    blit_func = DI.composite_dover_oa;
	    break;

	  case NSCompositeDestinationIn:
	    return -1; /* noop */

	  case NSCompositeDestinationOut:
	    return NSCompositeClear;

	  case NSCompositePlusLighter:
	    blit_func = DI.composite_plusl_oa;
	    break;
	  case NSCompositePlusDarker:
	    blit_func = DI.composite_plusd_oa;
	    break;
	  }
      }
    else if (dst_opaque)
      { /* source has alpha, destination is opaque */
	switch (op)
	  {
	  case NSCompositeSourceOver:
	  case NSCompositeSourceAtop:
	    blit_func = DI.composite_sover_ao;
	    break;

	  case NSCompositeSourceIn:
	    return NSCompositeCopy;

	  case NSCompositeSourceOut:
	    return NSCompositeClear;

	  case NSCompositeDestinationOver:
	    return -1; /* noop */

	  case NSCompositeDestinationIn:
	  case NSCompositeDestinationOut:
	  case NSCompositeDestinationAtop:
	  case NSCompositeXOR:
	    *dst_needs_alpha = YES;
	    goto both_have_alpha;

	  case NSCompositePlusLighter:
	    blit_func = DI.composite_plusl_ao;
	    break;
	  case NSCompositePlusDarker:
	    blit_func = DI.composite_plusd_ao;
	    break;
	  }
      }
    else
      { /* both source and destination have alpha */
      both_have_alpha:
	switch (op)
	  {
	  case NSCompositeSourceOver:
	    blit_func = DI.composite_sover_aa;
	    break;
	  case NSCompositeSourceIn:
	    blit_func = DI.composite_sin_aa;
	    break;
	  case NSCompositeSourceOut:
	    blit_func = DI.composite_sout_aa;
	    break;
	  case NSCompositeSourceAtop:
	    blit_func = DI.composite_satop_aa;
	    break;
	  case NSCompositeDestinationOver:
	    blit_func = DI.composite_dover_aa;
	    break;
	  case NSCompositeDestinationIn:
	    blit_func = DI.composite_din_aa;
	    break;
	  case NSCompositeDestinationOut:
	    blit_func = DI.composite_dout_aa;
	    break;
	  case NSCompositeDestinationAtop:
	    blit_func = DI.composite_datop_aa;
	    break;
	  case NSCompositeXOR:
	    blit_func = DI.composite_xor_aa;
	    break;
	  case NSCompositePlusLighter:
	    blit_func = DI.composite_plusl_aa;
	    break;
	  case NSCompositePlusDarker:
	    blit_func = DI.composite_plusd_aa;
	    break;
	  }
      }
  *blit_func_r = blit_func;
  return op;
}



- (void) compositeGState: (GSGState *)source
                fromRect: (NSRect)aRect
                 toPoint: (NSPoint)aPoint
                      op: (NSCompositingOperation)op
{
  ARTGState *ags = (ARTGState *)source;
  NSRect sr, dr;
  unsigned char *dst, *dst_alpha, *src, *src_alpha;

  void (*blit_func)(composite_run_t *c, int num) = NULL;

  int sx, sy;
  int x0, y0, x1, y1;

  int sbpl, dbpl;
  int asbpl, adbpl;

  /* 0 = top->down, 1 = bottom->up */
  /*
    TODO: this does not handle the horizontal case
    either 0=top->down, left->right, 2=top->down, right->left
    or keep 0 and add 2=top->down, make temporary copy of source
    could allocate a temporary array on the stack large enough to hold
    one row and do the operations on it
  */
  /* currently 2=top->down, be careful with overlapping rows */
  /* order=1 is handled generically by flipping sbpl and dbpl and
     adjusting the pointers. only order=2 needs to be handled for
     each operator */
  int order;


  if (!wi || !wi->data || !ags->wi || !ags->wi->data) return;
  if (all_clipped) return;


  {
    BOOL dst_needs_alpha;
    op = [self _composite_func: !ags->wi->has_alpha : NO
	     : !wi->has_alpha : &dst_needs_alpha
	     : op : &blit_func];
    if (op == -1)
      return;

    if (dst_needs_alpha)
      {
	[wi needsAlpha];
	if (!wi->has_alpha)
	  return;
      }
  }


  /* these ignore the source window, so we send them off to
     compositerect: op: */
  if (op == NSCompositeClear || op == NSCompositeHighlight)
    {
      [self compositerect: NSMakeRect(aPoint.x, aPoint.y,
				      aRect.size.width, aRect.size.height)
	    op: op];
      return;
    }


  /* Set up all the pointers and clip things */

  dbpl = wi->bytes_per_line;
  sbpl = ags->wi->bytes_per_line;

  sr = aRect;
  sr = [ags->ctm rectInMatrixSpace: sr];
  sr.origin.y = ags->wi->sy - sr.origin.y - sr.size.height;
  sx = sr.origin.x;
  sy = sr.origin.y;

  dr = aRect;
  dr.origin = aPoint;
  dr = [ctm rectInMatrixSpace: dr];
  dr.origin.y = wi->sy - dr.origin.y - dr.size.height;

  x0 = dr.origin.x;
  y0 = dr.origin.y;
  x1 = dr.origin.x + dr.size.width;
  y1 = dr.origin.y + dr.size.height;

  if (clip_x0 > x0) /* TODO: ??? */
    {
      sx += clip_x0 - x0;
      x0 = clip_x0;
    }
  if (clip_y0 > y0)
    {
      sy += clip_y0 - y0;
      y0 = clip_y0;
    }

  if (x1 > clip_x1)
    x1 = clip_x1;
  if (y1 > clip_y1)
    y1 = clip_y1;

  if (x0 >= x1 || y0 >= y1) return;

  /* TODO: clip source? how?
     we should at least clip the source to the source window to avoid
     crashes */

  dst = wi->data + x0 * DI.bytes_per_pixel + y0 * dbpl;
  src = ags->wi->data + sx * DI.bytes_per_pixel + sy * sbpl;

  if (ags->wi->has_alpha && op == NSCompositeCopy)
    {
      [wi needsAlpha];
      if (!wi->has_alpha)
	return;
    }

  if (ags->wi->has_alpha)
    {
      if (DI.inline_alpha)
	src_alpha = src;
      else
	src_alpha = ags->wi->alpha + sx + sy * ags->wi->sx;
      asbpl = ags->wi->sx;
    }
  else
    {
      src_alpha = NULL;
      asbpl = 0;
    }

  if (wi->has_alpha)
    {
      if (DI.inline_alpha)
	dst_alpha = dst;
      else
	dst_alpha = wi->alpha + x0 + y0 * wi->sx;
      adbpl = wi->sx;
    }
  else
    {
      dst_alpha = NULL;
      adbpl = 0;
    }

  y1 -= y0;
  x1 -= x0;

  /* To handle overlapping areas properly, we sometimes need to do
     things bottom-up instead of top-down. If so, we flip the
     coordinates here. */
  order = 0;
  if (ags == self && sy <= y0)
    {
      order = 1;
      dst += dbpl * (y1 - 1);
      src += sbpl * (y1 - 1);
      dst_alpha += adbpl * (y1 - 1);
      src_alpha += asbpl * (y1 - 1);
      dbpl = -dbpl;
      sbpl = -sbpl;
      adbpl = -adbpl;
      asbpl = -asbpl;
      if (sy == y0)
	{ /* TODO: pure horizontal, not handled properly in all
	     cases */
	  if ((sx >= x0 && sx <= x0 + x1) || (x0 >= sx && x0 <= x0 + x1))
	    order = 2;
	}
    }

  if (op == NSCompositeCopy)
    { /* TODO: for inline alpha, make sure even opaque destinations have
	 alpha properly filled in */
      int y;

      if (!DI.inline_alpha && wi->has_alpha)
	{
	  if (ags->wi->has_alpha)
	    for (y = 0; y < y1; y++, dst_alpha += adbpl, src_alpha += asbpl)
	      memmove(dst_alpha, src_alpha, x1);
	  else
	    for (y = 0; y < y1; y++, dst_alpha += adbpl)
	      memset(dst_alpha, 0xff, x1);
	}

      x1 *= DI.bytes_per_pixel;
      for (y = 0; y < y1; y++, dst += dbpl, src += sbpl)
	memmove(dst, src, x1);
      /* TODO: worth the complexity? */
/*	{
		int y;
		x1 *= DI.bytes_per_pixel;
		for (y = 0; y < y1; y++, dst += dbpl, src += sbpl)
			memcpy(dst, src, x1);
	}*/
      return;
    }


  if (!blit_func)
    {
      NSLog(@"unimplemented: compositeGState: %p fromRect: (%g %g)+(%g %g) toPoint: (%g %g)  op: %i",
	    source,
	    aRect.origin.x, aRect.origin.y,
	    aRect.size.width, aRect.size.height,
	    aPoint.x, aPoint.y,
	    op);
      return;
    }

  /* this breaks the alpha pointer in some, but that's ok since in
     all those cases, the alpha pointer isn't used (inline alpha or
     no alpha) */
  if (order == 2)
    {
      unsigned char tmpbuf[x1 * DI.bytes_per_pixel];
      int y;
      composite_run_t c;

      c.dst = dst;
      c.dsta = dst_alpha;
      c.src = src;
      c.srca = src_alpha;
      for (y = 0; y < y1; y++, c.dst += dbpl, c.src += sbpl)
	{
	  /* don't need to copy alpha since it is either
	     separate and won't be written to or part of the
	     data */
	  /* TODO: this only holds if there's no destination
	     alpha, which is no longer true. ignore for now; why
	     would someone sourceover something on itself? */
	  /* TODO: this looks broken. where is tmpbuf used? */
	  memcpy(tmpbuf, src, x1 * DI.bytes_per_pixel);
	  blit_func(&c, x1);
	  c.srca += asbpl;
	  c.dsta += adbpl;
	}
    }
  else
    {
      int y;
      composite_run_t c;

      c.dst = dst;
      c.dsta = dst_alpha;
      c.src = src;
      c.srca = src_alpha;
      for (y = 0; y < y1; y++, c.dst += dbpl, c.src += sbpl)
	{
	  blit_func(&c, x1);
	  c.srca += asbpl;
	  c.dsta += adbpl;
	}
    }
}

- (void) dissolveGState: (GSGState *)source
               fromRect: (NSRect)aRect
                toPoint: (NSPoint)aPoint
                  delta: (float)delta
{
  NSLog(@"ignoring dissolveGState: %08x fromRect: (%g %g)+(%g %g) toPoint: (%g %g) delta: %g",
	source,
	aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height,
	aPoint.x, aPoint.y, delta);
}

- (void) compositerect: (NSRect)aRect
                    op: (NSCompositingOperation)op
{
/* much setup code shared with compositeGState:... */
  NSRect dr;
  unsigned char *dst;

  int x0, y0, x1, y1;

  int dbpl;

  void (*blit_func)(composite_run_t *c, int num);

  if (!wi || !wi->data) return;
  if (all_clipped) return;

  dbpl = wi->bytes_per_line;

  dr = aRect;
  dr = [ctm rectInMatrixSpace: dr];
  dr.origin.y = wi->sy - dr.origin.y - dr.size.height;

  x0 = dr.origin.x;
  y0 = dr.origin.y;
  x1 = dr.origin.x + dr.size.width;
  y1 = dr.origin.y + dr.size.height;

  if (clip_x0 > x0)
    x0 = clip_x0;
  if (clip_y0 > y0)
    y0 = clip_y0;

  if (x1 > clip_x1)
    x1 = clip_x1;
  if (y1 > clip_y1)
    y1 = clip_y1;

  if (x0 >= x1 || y0 >= y1) return;

  dst = wi->data + x0 * DI.bytes_per_pixel + y0 * dbpl;

  y1 -= y0;
  x1 -= x0;

  {
    BOOL dest_needs_alpha;

    /* TODO: which color? using fill_color for now */
    op = [self _composite_func: fill_color[3] == 255 : fill_color[3] == 0
	     : !wi->has_alpha : &dest_needs_alpha
	     : op : &blit_func];

    if (op == -1)
      return;

    if (dest_needs_alpha)
      {
	[wi needsAlpha];
	if (!wi->has_alpha)
	  return;
      }
  }

  if (op == NSCompositeClear)
    {
      int y;
      [wi needsAlpha];
      if (!wi->has_alpha)
	return;
      if (!DI.inline_alpha)
	{
	  unsigned char *dsta;
	  dsta = wi->alpha + x0 + y0 * wi->sx;
	  for (y = 0; y < y1; y++, dsta += wi->sx)
	    memset(dsta, 0, x1);
	}
      x1 *= DI.bytes_per_pixel;
      for (y = 0; y < y1; y++, dst += dbpl)
	memset(dst, 0, x1);
      return;
    }
  else if (op == NSCompositeHighlight)
    {
      int y, n;
      /* This must be reversible, which limits what we can
	 do. */
      x1 *= DI.bytes_per_pixel;
      for (y = 0; y < y1; y++, dst += dbpl)
	{
	  unsigned char *d = dst;
	  for (n = x1; n; n--, d++)
	    (*d) ^= 0xff;
	}
      return;
    }
  else if (op == NSCompositeCopy)
    {
      render_run_t ri;
      int y;
      ri.dst = dst;
      /* We don't want to blend, so we premultiply and fill the
	 alpha channel manually. */
      ri.a = fill_color[3];
      ri.r = (fill_color[0] * ri.a + 0xff) >> 8;
      ri.g = (fill_color[1] * ri.a + 0xff) >> 8;
      ri.b = (fill_color[2] * ri.a + 0xff) >> 8;
      for (y = 0; y < y1; y++, ri.dst += dbpl)
	DI.render_run_opaque(&ri, x1);

      if (ri.a != 255)
	[wi needsAlpha];
      if (wi->has_alpha)
	{
	  if (DI.inline_alpha)
	    {
	      int n;
	      unsigned char *p;
	      for (y = 0; y < y1; y++, dst += dbpl)
		{ /* TODO: needs to change to support inline
		     alpha for non-32-bit modes */
		  for (p = dst, n = x1; n; n--, p += 4)
		    dst[DI.inline_alpha_ofs] = ri.a;
		}
	    }
	  else
	    {
	      unsigned char *dsta;
	      dsta = wi->alpha + x0 + y0 * wi->sx;
	      for (y = 0; y < y1; y++, dsta += wi->sx)
		memset(dsta, ri.a, x1);
	    }
	}
      return;
    }
  else if (blit_func)
    {
      /* this is slightly ugly, but efficient */
      unsigned char buf[DI.bytes_per_pixel * x1];
      unsigned char abuf[fill_color[3] == 255? 1 : x1];
      int y;
      composite_run_t c;

      c.src = buf;
      if (fill_color[3] != 255)
	c.srca = abuf;
      else
	c.srca = NULL;
      c.dst = dst;
      if (wi->has_alpha)
	c.dsta = wi->alpha + x0 + y0 * wi->sx;
      else
	c.dsta = NULL;

      {
	render_run_t ri;
	ri.dst = buf;
	ri.dsta = NULL;
	/* Note that we premultiply _here_ and set the alpha
	   channel manually (for speed; no reason to do slow
	   blending when we just want a straight blit of all
	   channels). */
	ri.a = fill_color[3];
	ri.r = (fill_color[0] * ri.a + 0xff) >> 8;
	ri.g = (fill_color[1] * ri.a + 0xff) >> 8;
	ri.b = (fill_color[2] * ri.a + 0xff) >> 8;
	DI.render_run_opaque(&ri, x1);
	if (fill_color[3] != 255)
	  {
	    if (DI.inline_alpha)
	      {
		int i;
		unsigned char *s;
		/* TODO: needs to change to support inline
		   alpha for non-32-bit modes */
		for (i = 0, s = buf + DI.inline_alpha_ofs; i < x1; i++, s += 4)
		  *s = ri.a;
	      }
	    else
	      memset(abuf, ri.a, x1);
	  }
      }

      for (y = 0; y < y1; y++, c.dst += dbpl, c.dsta += wi->sx)
	blit_func(&c, x1);
      return;
    }

  NSLog(@"unimplemented compositerect: (%g %g)+(%g %g)  op: %i",
	aRect.origin.x, aRect.origin.y,
	aRect.size.width, aRect.size.height,
	op);
}

@end

