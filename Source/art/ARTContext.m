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

#include <math.h>

#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>
#include <AppKit/NSColor.h>

#include "ARTGState.h"

#include "x11/XWindowBuffer.h"
#include "blit.h"
#include "ftfont.h"


#ifndef PI
#define PI 3.14159265358979323846264338327950288
#endif


/*

** subclassResponsibility **
Note that these aren't actually subclassResponsibility anymore; instead
of crashing, they just print a warning.

- (void) dissolveGState: (GSGState *)source
               fromRect: (NSRect)aRect
                toPoint: (NSPoint)aPoint
                  delta: (float)delta

- (void) DPSashow: (float)x : (float)y : (const char*)s
- (void) DPSawidthshow: (float)cx : (float)cy : (int)c : (float)ax : (float)ay 
- (void) DPSwidthshow: (float)x : (float)y : (int)c : (const char*)s
DPSxshow, DPSyshow, DPSxyshow


** Other unimplemented stuff **

FontInfo:
-(void) set

Context:
- (NSColor *) NSReadPixel: (NSPoint) location

*/


/* Portions based on gnustep-back code, eg.: */
/* GSGState - Generic graphic state

   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Date: Mar 2002
   
   This file is part of the GNU Objective C User Interface Library.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */


draw_info_t ART_DI;


@implementation ARTGState


/* TODO:
optimize all this. passing device_color_t structures around by value is
very expensive
*/
-(void) setColor: (device_color_t *)color  state: (color_state_t)cState
{
	device_color_t c;
	unsigned char r,g,b;

	[super setColor: color  state: cState];
	if (cState&(COLOR_FILL|COLOR_STROKE))
	{
		c=fillColor;
		gsColorToRGB(&c); /* TODO: check this */
		if (c.field[0]>1.0) c.field[0]=1.0;
		if (c.field[0]<0.0) c.field[0]=0.0;
		r=c.field[0]*255;
		if (c.field[1]>1.0) c.field[1]=1.0;
		if (c.field[1]<0.0) c.field[1]=0.0;
		g=c.field[1]*255;
		if (c.field[2]>1.0) c.field[2]=1.0;
		if (c.field[2]<0.0) c.field[2]=0.0;
		b=c.field[2]*255;

		if (cState&COLOR_FILL)
		{
			fill_color[0]=r;
			fill_color[1]=g;
			fill_color[2]=b;
			fill_color[3]=fillColor.field[AINDEX]*255;
		}
		if (cState&COLOR_STROKE)
		{
			stroke_color[0]=r;
			stroke_color[1]=g;
			stroke_color[2]=b;
			stroke_color[3]=strokeColor.field[AINDEX]*255;
		}
	}
}

/* specially optimized versions (since these are common and simple) */
-(void) DPSsetgray: (float)gray
{
  if (gray < 0.0) gray = 0.0;
  if (gray > 1.0) gray = 1.0;

  fillColor.space = strokeColor.space = gray_colorspace;
  fillColor.field[0] = strokeColor.field[0] = gray;
  cstate = COLOR_FILL | COLOR_STROKE;

  stroke_color[0] = stroke_color[1] = stroke_color[2] =
    fill_color[0] = fill_color[1] = fill_color[2] = gray * 255;
}

-(void) DPSsetalpha: (float)a
{
  if (a < 0.0) a = 0.0;
  if (a > 1.0) a = 1.0;
  fillColor.field[AINDEX] = strokeColor.field[AINDEX] = a;
  stroke_color[3] = fill_color[3] = a * 255;
}

- (void) DPSsetrgbcolor: (float)r : (float)g : (float)b
{
  if (r < 0.0) r = 0.0; if (r > 1.0) r = 1.0;
  if (g < 0.0) g = 0.0; if (g > 1.0) g = 1.0;
  if (b < 0.0) b = 0.0; if (b > 1.0) b = 1.0;

  fillColor.space = strokeColor.space = rgb_colorspace;
  fillColor.field[0] = strokeColor.field[0] = r;
  fillColor.field[1] = strokeColor.field[1] = g;
  fillColor.field[2] = strokeColor.field[2] = b;
  cstate = COLOR_FILL | COLOR_STROKE;

  stroke_color[0] = fill_color[0] = r * 255;
  stroke_color[1] = fill_color[1] = g * 255;
  stroke_color[2] = fill_color[2] = b * 255;
}


/* ----------------------------------------------------------------------- */
/* Text operations */
/* ----------------------------------------------------------------------- */
- (void) DPSashow: (float)x : (float)y : (const char*)s
{ /* TODO: adds (x,y) in user space to each glyph's x/y advancement */
	NSLog(@"ignoring DPSashow: %g : %g : '%s'",x,y,s);
}

- (void) DPSawidthshow: (float)cx : (float)cy : (int)c : (float)ax : (float)ay 
		      : (const char*)s
{ /* TODO: add (ax,ay) in user space to each glyph's x/y advancement and
 additionally add (cx,cy) to the character c's advancement */
	NSLog(@"ignoring DPSawidthshow: %g : %g : %i : %g : %g : '%s'",
		cx,cy,c,ax,ay,s);
}

- (void) DPScharpath: (const char*)s : (int)b
{ /* TODO: handle b? will freetype ever give us a stroke-only font? */
	NSPoint p;

	if ([path isEmpty]) return;
	p=[self currentPoint];

	[(id<FTFontInfo>)[font fontInfo]
		outlineString: s
		at: p.x:p.y
		gstate: self];
	[self DPSclosepath];
}

- (void) DPSshow: (const char*)s
{
  NSPoint p;
  int x, y;

  if (!wi || !wi->data) return;
  if (all_clipped)
    return;

  if ([path isEmpty]) return;
  p = [path currentPoint];

  x = p.x;
  y = wi->sy - p.y;
  [(id<FTFontInfo>)[font fontInfo]
    drawString: s
    at: x:y
    to: clip_x0:clip_y0:clip_x1:clip_y1 : CLIP_DATA : wi->bytes_per_line
    color: fill_color[0]:fill_color[1]:fill_color[2]:fill_color[3]
    transform: ctm
    drawinfo: &DI];
  UPDATE_UNBUFFERED
}

- (void) DPSwidthshow: (float)x : (float)y : (int)c : (const char*)s
{ /* TODO: add (x,y) user-space to the character c's advancement */
	NSLog(@"ignoring DPSwidthshow: %g : %g : %i : '%s'",x,y,c,s);
}

- (void) DPSxshow: (const char*)s : (const float*)numarray : (int)size
{
  NSPoint p;
  int x, y;

  if (!wi || !wi->data) return;
  if (all_clipped)
    return;

  if ([path isEmpty]) return;
  p = [path currentPoint];

  x = p.x;
  y = wi->sy - p.y;
  [(id<FTFontInfo>)[font fontInfo]
    drawString: s
    at: x:y
    to: clip_x0:clip_y0:clip_x1:clip_y1 : CLIP_DATA : wi->bytes_per_line
    color: fill_color[0]:fill_color[1]:fill_color[2]:fill_color[3]
    transform: ctm
    deltas: numarray : size : 1];
  UPDATE_UNBUFFERED
}

- (void) DPSxyshow: (const char*)s : (const float*)numarray : (int)size
{
  NSPoint p;
  int x, y;

  if (!wi || !wi->data) return;
  if (all_clipped)
    return;

  if ([path isEmpty]) return;
  p = [path currentPoint];

  x = p.x;
  y = wi->sy - p.y;
  [(id<FTFontInfo>)[font fontInfo]
    drawString: s
    at: x:y
    to: clip_x0:clip_y0:clip_x1:clip_y1 : CLIP_DATA : wi->bytes_per_line
    color: fill_color[0]:fill_color[1]:fill_color[2]:fill_color[3]
    transform: ctm
    deltas: numarray : size : 3];
  UPDATE_UNBUFFERED
}

- (void) DPSyshow: (const char*)s : (const float*)numarray : (int)size
{
  NSPoint p;
  int x, y;

  if (!wi || !wi->data) return;
  if (all_clipped)
    return;

  if ([path isEmpty]) return;
  p = [path currentPoint];

  x = p.x;
  y = wi->sy - p.y;
  [(id<FTFontInfo>)[font fontInfo]
    drawString: s
    at: x:y
    to: clip_x0:clip_y0:clip_x1:clip_y1 : CLIP_DATA : wi->bytes_per_line
    color: fill_color[0]:fill_color[1]:fill_color[2]:fill_color[3]
    transform: ctm
    deltas: numarray : size : 2];
  UPDATE_UNBUFFERED
}


/* ----------------------------------------------------------------------- */
/* Gstate operations */
/* ----------------------------------------------------------------------- */
- (void) DPSinitgraphics
{
	[super DPSinitgraphics];

	line_width=1.0;
	linecapstyle=ART_PATH_STROKE_CAP_BUTT;
	linejoinstyle=ART_PATH_STROKE_JOIN_MITER;
	miter_limit=10.0;
	if (dash.n_dash)
	{
		free(dash.dash);
		dash.dash=NULL;
		dash.n_dash=0;
		do_dash=0;
	}
}

- (void) DPScurrentlinecap: (int*)linecap
{
	switch (linecapstyle)
	{
	default:
	case ART_PATH_STROKE_CAP_BUTT:
		*linecap=NSButtLineCapStyle;
		break;
	case ART_PATH_STROKE_CAP_ROUND:
		*linecap=NSRoundLineCapStyle;
		break;
	case ART_PATH_STROKE_CAP_SQUARE:
		*linecap=NSSquareLineCapStyle;
		break;
	}
}

- (void) DPScurrentlinejoin: (int*)linejoin
{
	switch (linejoinstyle)
	{
	default:
	case ART_PATH_STROKE_JOIN_MITER:
		*linejoin=NSMiterLineJoinStyle;
		break;
	case ART_PATH_STROKE_JOIN_ROUND:
		*linejoin=NSRoundLineJoinStyle;
		break;
	case ART_PATH_STROKE_JOIN_BEVEL:
		*linejoin=NSBevelLineJoinStyle;
		break;
	}
}

- (void) DPScurrentlinewidth: (float*)width
{
	*width=line_width;
}

- (void) DPScurrentmiterlimit: (float*)limit
{
	*limit=miter_limit;
}

- (void) DPScurrentstrokeadjust: (int*)b
{
	/* TODO We never stroke-adjust, see DPSsetstrokeadjust. */
	*b=0;
}

- (void) DPSsetdash: (const float*)pat : (int)size : (float)offs
{
	int i;

	if (dash.n_dash)
	{
		free(dash.dash);
		dash.dash=NULL;
		dash.n_dash=0;
		do_dash=0;
	}

	if (size>0)
	{
		dash.offset=offs;
		dash.n_dash=size;
		dash.dash=malloc(sizeof(double)*size);
		if (!dash.dash)
		{
			/* Revert to no dash. Better than crashing. */
			dash.n_dash=0;
			dash.offset=0;
			do_dash=0;
		}
		else
		{
			for (i=0;i<size;i++)
				dash.dash[i]=pat[i];
			do_dash=1;
		}
	}
}

- (void) DPSsetlinecap: (int)linecap
{
	switch (linecap)
	{
	default:
	case NSButtLineCapStyle:
		linecapstyle=ART_PATH_STROKE_CAP_BUTT;
		break;
	case NSRoundLineCapStyle:
		linecapstyle=ART_PATH_STROKE_CAP_ROUND;
		break;
	case NSSquareLineCapStyle:
		linecapstyle=ART_PATH_STROKE_CAP_SQUARE;
		break;
	}
}

- (void) DPSsetlinejoin: (int)linejoin
{
	switch (linejoin)
	{
	default:
	case NSMiterLineJoinStyle:
		linejoinstyle=ART_PATH_STROKE_JOIN_MITER;
		break;
	case NSRoundLineJoinStyle:
		linejoinstyle=ART_PATH_STROKE_JOIN_ROUND;
		break;
	case NSBevelLineJoinStyle:
		linejoinstyle=ART_PATH_STROKE_JOIN_BEVEL;
		break;
	}
}

- (void) DPSsetlinewidth: (float)width
{
	line_width=width;
	/* TODO? handle line_width=0 properly */
	if (line_width<=0) line_width=1;
}

- (void) DPSsetmiterlimit: (float)limit
{
	miter_limit=limit;
}

- (void) DPSsetstrokeadjust: (int)b
{
	/* Since we anti-alias stroke-adjustment isn't really applicable.
	TODO:
	However, it might be useful to handle stroke-adjusting by snapping
	to whole pixels when rendering to avoid anti-aliasing of rectangles
	and straight lines. */
}

@end


@interface ARTGState (internal_stuff)
-(void) _setup_stuff: (gswindow_device_t *)win : (int)x : (int)y;
-(void) GSCurrentDevice: (void **)device : (int *)x : (int *)y;
@end

@implementation ARTGState (internal_stuff)


- (void) dealloc
{
	if (dash.dash)
		free(dash.dash);

	if (clip_span)
		free(clip_span);
	if (clip_index)
		free(clip_index);

	DESTROY(wi);

	[super dealloc];
}


-(id) deepen
{
  [super deepen];

  if (dash.dash)
  {
	double *tmp=malloc(sizeof(double)*dash.n_dash);
	if (tmp)
	{
		memcpy(tmp,dash.dash,sizeof(double)*dash.n_dash);
		dash.dash=tmp;
	}
	else
	{
		dash.dash=NULL;
		dash.n_dash=0;
		do_dash=0;
	}
  }

  if (clip_span)
  {
	unsigned int *n;
	n=malloc(sizeof(unsigned int)*clip_num_span);
	if (n)
	{
		memcpy(n,clip_span,sizeof(unsigned int)*clip_num_span);
		clip_span=n;
		n=malloc(sizeof(unsigned int *)*(clip_sy+1));
		if (n)
		{
			memcpy(n,clip_index,sizeof(unsigned int *)*(clip_sy+1));
			clip_index = n;
		}
		else
		{
			free(clip_span);
			clip_span=clip_index=NULL;
			clip_num_span=0;
		}
	}
	else
	{
		clip_span=clip_index=NULL;
		clip_num_span=0;
	}
  }

  wi=RETAIN(wi);

  return self;
}

-(void) _setup_stuff: (gswindow_device_t *)window : (int)x : (int)y
{
	struct XWindowBuffer_depth_info_s di;

	XWindowBuffer *new_wi;
	[self setOffset: NSMakePoint(x, y)];

	di.drawing_depth = DI.drawing_depth;
	di.bytes_per_pixel = DI.bytes_per_pixel;
	di.inline_alpha = DI.inline_alpha;
	di.inline_alpha_ofs = DI.inline_alpha_ofs;
	new_wi=[XWindowBuffer windowBufferForWindow: window  depthInfo: &di];
	if (new_wi != wi)
	{
		DESTROY(wi);
		wi=new_wi;
	}
	else
	{
		DESTROY(new_wi);
	}
}

-(void) GSCurrentDevice: (void **)device : (int *)x : (int *)y
{
	if (x)
		*x = 0;
	if (y)
		*y = 0;
	if (device)
	{
		if (wi)
			*device = wi->window;
		else
			*device = NULL;
	}
}

@end


@implementation ARTContext

+ (void)initializeBackend
{
	NSLog(@"Initializing libart/freetype backend");

	[NSGraphicsContext setDefaultContextClass: [ARTContext class]];

	[FTFontInfo initializeBackend];
}



- (id) initWithContextInfo: (NSDictionary *)info
{
	NSString *contextType;
	contextType = [info objectForKey:
		NSGraphicsContextRepresentationFormatAttributeName];

	self = [super initWithContextInfo: info];
	if (contextType)
	{
		/* Most likely this is a PS or PDF context, so just return what
		   super gave us */
		return self;
	}

	/* Create a default gstate */
	gstate = [[ARTGState allocWithZone: [self zone]] initWithDrawContext: self];
	[gstate DPSsetalpha: 1.0];
	[gstate DPSsetlinewidth: 1.0];

	{
		Display *d=[(XGServer *)server xDisplay];
		Visual *v=DefaultVisual(d,DefaultScreen(d));
		int bpp=DefaultDepth(d,DefaultScreen(d));
		XImage *i=XCreateImage(d,v,bpp,ZPixmap,0,NULL,8,8,8,0);
		bpp=i->bits_per_pixel;
		XDestroyImage(i);

		artcontext_setup_draw_info(&DI,v->red_mask,v->green_mask,v->blue_mask,bpp);
	}

	return self;
}


- (void) flushGraphics
{ /* TODO: _really_ flush? (ie. force updates and wait for shm completion?) */
	XFlush([(XGServer *)server xDisplay]);
}

+(void) waitAllContexts
{
}


+(void) _gotShmCompletion: (Drawable)d
{
	[XWindowBuffer _gotShmCompletion: d];
}

-(void) gotShmCompletion: (Drawable)d
{
	[XWindowBuffer _gotShmCompletion: d];
}

//
// Read the Color at a Screen Position
//
- (NSColor *) NSReadPixel: (NSPoint) location
{
	NSLog(@"ignoring NSReadPixel: (%g %g)",location.x,location.y);
	return nil;
}

- (void) beep
{
	XBell([(XGServer *)server xDisplay], 50);
}

/* Private backend methods */
+(void) handleExposeRect: (NSRect)rect forDriver: (void *)driver
{
	[(XWindowBuffer *)driver _exposeRect: rect];
}

@end

@implementation ARTContext (ops)
- (void) GSSetDevice: (void*)device : (int)x : (int)y
{
	[(ARTGState *)gstate _setup_stuff: device : x : y];
}

-(void) GSCurrentDevice: (void **)device : (int *)x : (int *)y
{
	[(ARTGState *)gstate GSCurrentDevice: device : x : y];
}
@end

