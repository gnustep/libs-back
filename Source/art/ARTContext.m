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

#include <math.h>

#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>
#include <AppKit/NSColor.h>

#include "gsc/GSContext.h"
#include "gsc/GSGState.h"

#include "blit.h"
#include "ftfont.h"

#include "art/ARTContext.h"

#ifndef RDS
#include "x11/XGServer.h"
#include "x11/XGServerWindow.h"
#else
#include "rds/RDSClient.h"
#endif


#include <libart_lgpl/libart.h>
#include <libart_lgpl/art_svp_intersect.h>

#ifndef RDS
#include <X11/extensions/XShm.h>
#include <X11/extensions/shape.h>
#endif
#include <sys/ipc.h>
#include <sys/shm.h>


#ifndef PI
#define PI 3.14159265358979323846264338327950288
#endif


#ifndef RDS
static int use_shape_hack=0; /* this is an ugly hack :) */
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

- (void) DPSclip
- (void) DPSeoclip


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


static draw_info_t DI;


/*
WinImage maintains an XImage for a window. Each ARTGState that renders
to that window uses the same WinImage (and thus the same buffer, etc.).
*/

@interface WinImage : NSObject
{
@public
#ifdef RDS
	int window;
	RDSClient *remote;

	struct
	{
		int shmid;
		char *shmaddr;
	} shminfo;
#else
	gswindow_device_t *window;
	GC gc;
	Drawable drawable;
	XImage *ximage;
	Display *display;

	int use_shm;
	XShmSegmentInfo shminfo;
#endif


	/* While a XShmPutImage is in progress we don't try to call it
	again. The pending updates are stored here, and when we get the
	ShmCompletion event, we handle them. */
	int pending_put;     /* There are pending updates */
	NSRect pending_rect; /* in this rectangle. */

	int pending_event;   /* We're waiting for the ShmCompletion event. */


	unsigned char *data;
	int sx,sy;
	int bytes_per_line,bits_per_pixel,bytes_per_pixel;

	/* If has_alpha is 1 and alpha is NULL, the alpha is stored in data
	somehow. The drawing mechanism code should know how to deal with
	it. */
	unsigned char *alpha;
	int has_alpha;


	unsigned char *old_shape;
	int old_shape_size;
}

#ifdef RDS
+ winImageForWindow: (int)awindow  remote: (RDSClient *)remote;
#else
+ winImageForWindow: (gswindow_device_t *)awindow;
#endif

-(void) needsAlpha;

-(void) _gotShmCompletion;
-(void) _exposeRect: (NSRect)r;
@end


@interface ARTContext (shm_stuff)
+(void) _gotShmCompletion: (Drawable)d;
@end


/* Many states might render to the same window, so we need to make sure
that there's only one WinImage for each window. */
static WinImage **wimages;
static int num_wimages;


#ifndef RDS

@implementation WinImage

+ winImageForWindow: (gswindow_device_t *)awindow
{
	int i;
	WinImage *wi;

	for (i=0;i<num_wimages;i++)
	{
		if (wimages[i]->window==awindow)
			break;
	}
	if (i==num_wimages)
	{
		wi=[[WinImage alloc] init];
		wi->window=awindow;
		wimages=realloc(wimages,sizeof(WinImage *)*(num_wimages+1));
		if (!wimages)
		{
			NSLog(@"Out of memory (failed to allocate %i bytes)",
				sizeof(WinImage *)*(num_wimages+1));
			exit(1);
		}
		wimages[num_wimages++]=wi;
	}
	else
	{
		wi=wimages[i];
		wi=RETAIN(wi);
	}

	wi->gc=awindow->gc;
	wi->drawable=awindow->ident;
	wi->display=awindow->display;

	wi->window->gdriverProtocol=GDriverHandlesExpose|GDriverHandlesBacking;
	wi->window->gdriver=wi;

	/* TODO: resolve properly.
 	-x11 is creating buffers before I have a chance to tell it not to, so
	I'm freeing them here to reduce memory consumption (and prevent
	leaks, though that should be fixed now) */
	if (awindow->buffer)
	{
		XFreePixmap (awindow->display, awindow->buffer);
		awindow->buffer=0;
	}
	if (awindow->alpha_buffer)
	{
		XFreePixmap (awindow->display, awindow->alpha_buffer);
		awindow->alpha_buffer=0;
	}

	/* create the image if necessary */
	if (!wi->ximage ||
	    wi->sx!=awindow->xframe.size.width ||
	    wi->sy!=awindow->xframe.size.height)
	{
		wi->sx=wi->window->xframe.size.width;
/*		printf("%@ updating image for %p (%gx%g)\n",wi,wi->window,
			wi->window->xframe.size.width,wi->window->xframe.size.height);*/
		if (wi->ximage)
		{
			if (wi->use_shm)
			{
				XShmDetach(wi->display,&wi->shminfo);
				XDestroyImage(wi->ximage);
				shmdt(wi->shminfo.shmaddr);
			}
			else
				XDestroyImage(wi->ximage);
		}
		wi->has_alpha=0;
		if (wi->alpha)
		{
			free(wi->alpha);
			wi->alpha=NULL;
		}

		wi->pending_put=wi->pending_event=0;

		wi->ximage=NULL;

		/* Use XShm if possible, else fall back to normal XImage:s */
		if (XShmQueryExtension(wi->display))
		{
			wi->use_shm=1;
			wi->ximage=XShmCreateImage(wi->display,
				DefaultVisual(wi->display,DefaultScreen(wi->display)),
				DI.drawing_depth,ZPixmap,NULL,&wi->shminfo,
				wi->window->xframe.size.width,
				wi->window->xframe.size.height);
		}
		if (wi->ximage)
		{
			/* TODO: only use shared memory for 'real' on-screen
			windows. how can we tell? */
			wi->shminfo.shmid=shmget(IPC_PRIVATE,
				wi->ximage->bytes_per_line*wi->ximage->height,
				IPC_CREAT|0700);

			if (!wi->shminfo.shmid==-1)
				NSLog(@"shmget() failed"); /* TODO */
/*				printf("shminfo.shmid=%08x  %i bytes (%ix%i)\n",
					wi->shminfo.shmid,wi->ximage->bytes_per_line*wi->ximage->height,
					wi->ximage->width,wi->ximage->height);*/
			wi->shminfo.shmaddr=wi->ximage->data=shmat(wi->shminfo.shmid,0,0);

			/* Mark the segment as destroyed now. Since we're
			attached, it won't actually be destroyed, but if we
			crashed before doing this, it wouldn't be destroyed
			despite nobody being attached anymore. */
			shmctl(wi->shminfo.shmid,IPC_RMID,0);

//			printf("addr=%p\n",wi->shminfo.shmaddr);
			wi->shminfo.readOnly=1;
			if (!XShmAttach(wi->display,&wi->shminfo))
				NSLog(@"XShmAttach() failed");
		}
		else
		{
			NSLog(@"failed to create shared memory image, using normal XImage:s");
			wi->use_shm=0;
			wi->ximage=XCreateImage(wi->display,DefaultVisual(wi->display,DefaultScreen(wi->display)),
				DI.drawing_depth,ZPixmap,0,NULL,
				wi->window->xframe.size.width,wi->window->xframe.size.height,8,0);
			wi->ximage->data=malloc(wi->ximage->height*wi->ximage->bytes_per_line);
			if (!wi->ximage->data)
			{
				XDestroyImage(wi->ximage);
				wi->ximage=NULL;
			}
/*TODO?			wi->ximage=XGetImage(wi->display,wi->drawable,
				0,0,wi->window->xframe.size.width,wi->window->xframe.size.height,
				-1,ZPixmap);*/
		}
	}

	if (wi->ximage)
	{
		wi->sx=wi->ximage->width;
		wi->sy=wi->ximage->height;
		wi->data=wi->ximage->data;
		wi->bytes_per_line=wi->ximage->bytes_per_line;
		wi->bits_per_pixel=wi->ximage->bits_per_pixel;
		wi->bytes_per_pixel=wi->bits_per_pixel/8;
//		NSLog(@"%@ ximage=%p data=%p\n",wi->ximage,wi->data);
	}
	else
	{
		NSLog(@"Warning: failed to create image for window");
		wi->data=NULL;
	}

	return wi;
}


extern int XShmGetEventBase(Display *d);

-(void) _gotShmCompletion
{
	if (!use_shm)
		return;

	pending_event=0;
	if (pending_put)
	{
		NSRect r=pending_rect;
		pending_put=0;
		if (r.origin.x+r.size.width>window->xframe.size.width)
		{
			r.size.width=window->xframe.size.width-r.origin.x;
			if (r.size.width<=0)
				return;
		}
		if (r.origin.y+r.size.height>window->xframe.size.height)
		{
			r.size.height=window->xframe.size.height-r.origin.y;
			if (r.size.height<=0)
				return;
		}
		if (!XShmPutImage(display,drawable,gc,ximage,
			r.origin.x,r.origin.y,
			r.origin.x,r.origin.y,
			r.size.width,r.size.height,
			1))
		{
			NSLog(@"XShmPutImage failed?");
		}
		else
		{
			pending_event=1;
		}
	}
//	XFlush(window->display);
}

-(void) _exposeRect: (NSRect)r
{
/* TODO: Somehow, we can get negative coordinates in the rectangle. So far
I've tracked them back to [NSWindow flushWindow]. Should probably figure
out where they're coming from originally, and see if they really should be
negative. (Seems to happen when a window is created or resized, so possibly
something is refreshing while coordinates are still invalid.

Also, just about every resize of a window causes a few calls here with
rects in the new size before we are updated.

For now, we just intersect with our known size to avoid problems with X.
*/

	r=NSIntersectionRect(r,NSMakeRect(0,0,
		window->xframe.size.width,window->xframe.size.height));
	if (NSIsEmptyRect(r))
		return;

	if (use_shm)
	{

/* HACK: lets try to use shaped windows to get some use out of destination
alpha */
if (has_alpha && use_shape_hack)
{
static int warn=0;
	Pixmap p;
	int dsize=((sx+7)/8)*sy;
	unsigned char *buf=malloc(dsize);
	unsigned char *dst;
	int bofs;
	unsigned char *a;
	int as;
	int i,x;

	if (!warn)
		NSLog(@"Warning: activating shaped windows");
	warn=1;

	memset(buf,0xff,dsize);

#define CUTOFF 128

	if (DI.inline_alpha)
	{
		a=data+DI.inline_alpha_ofs;
		as=4;
	}
	else
	{
		a=alpha;
		as=1;
	}

	for (bofs=0,i=sx*sy,x=sx,dst=buf;i;i--,a+=as)
	{
		if (*a<CUTOFF)
		{
			*dst=*dst&~(1<<bofs);
		}
		bofs++;
		if (bofs==8)
		{
			dst++;
			bofs=0;
		}
		x--;
		if (!x)
		{
			if (bofs)
			{
				bofs=0;
				dst++;
			}
			x=sx;
		}
	}
#undef CUTOFF
//NSLog(@"check shape");
	if (old_shape_size==dsize && !memcmp(old_shape,buf,dsize))
	{
		free(buf);
//		NSLog(@"  same shape");
	}
	else
	{
//		NSLog(@"  updating");
		p=XCreatePixmapFromBitmapData(display,window->ident,buf,sx,sy,1,0,1);
		free(old_shape);
		old_shape=buf;
		old_shape_size=dsize;
		XShapeCombineMask(display,window->ident,
			ShapeBounding,0,0,p,ShapeSet);
		XFreePixmap(display,p);
	}
}

		if (pending_event)
		{
			if (!pending_put)
			{
				pending_put=1;
				pending_rect=r;
			}
			else
			{
				pending_rect=NSUnionRect(pending_rect,r);
			}
		}
		else
		{
			pending_put=0;
			if (!XShmPutImage(display,drawable,gc,ximage,
				r.origin.x,r.origin.y,
				r.origin.x,r.origin.y,
				r.size.width,r.size.height,
				1))
			{
				NSLog(@"XShmPutImage failed?");
			}
			else
			{
				pending_event=1;
			}
		}

		/* Performance hack. Check right away for ShmCompletion
		events. */
		{
			XEvent e;
			while (XCheckTypedEvent(window->display,
				XShmGetEventBase(window->display)+ShmCompletion,
				&e))
			{
				[ARTContext _gotShmCompletion:
					((XShmCompletionEvent *)&e)->drawable];
			}
		}
	}
	else if (ximage)
		XPutImage(display,drawable,gc,ximage,
			r.origin.x,r.origin.y,
			r.origin.x,r.origin.y,
			r.size.width,r.size.height);
}

-(void) needsAlpha
{
	if (has_alpha)
		return;

//	NSLog(@"needs alpha for %p: %ix%i",self,sx,sy);

	if (DI.inline_alpha)
	{
		int i;
		unsigned char *s;
		alpha=NULL;
		has_alpha=1;
		/* fill the alpha channel */
		/* TODO: is +=4 correct? yes, but only because the only modes
		with inline alpha are 32 bit */
		for (i=0,s=data+DI.inline_alpha_ofs;i<sx*sy;i++,s+=4)
			*s=0xff;
		return;
	}

	alpha=malloc(sx*sy);
	if (!alpha)
	{
		NSLog(@"Warning! Failed to allocate alpha buffer for window!");
		return;
	}

//	NSLog(@"got buffer at %p",alpha);

	has_alpha=1;
	memset(alpha,0xff,sx*sy);
}

-(void) dealloc
{
	int i;

	for (i=0;i<num_wimages;i++)
		if (wimages[i]==self) break;
	if (i<num_wimages)
	{
		num_wimages--;
		for (;i<num_wimages;i++)
			wimages[i]=wimages[i+1];
	}

	if (ximage)
	{
		if (use_shm)
		{
			XShmDetach(display,&shminfo);
			XDestroyImage(ximage);
			shmdt(shminfo.shmaddr);
		}
		else
			XDestroyImage(ximage);
	}
	if (alpha)
		free(alpha);
	[super dealloc];
}

@end

#else

@implementation WinImage

static WinImage **wimages;
static int num_wimages;

+ winImageForWindow: (int)awindow  remote: (RDSClient *)aremote;
{
	int i;
	WinImage *wi;

	int x,y;

	for (i=0;i<num_wimages;i++)
	{
		if (wimages[i]->window==awindow)
			break;
	}
	if (i==num_wimages)
	{
		wi=[[WinImage alloc] init];
		wi->window=awindow;
		wi->remote=aremote;
		wimages=realloc(wimages,sizeof(WinImage *)*(num_wimages+1));
		if (!wimages)
		{
			NSLog(@"Out of memory (failed to allocate %i bytes)",
				sizeof(WinImage *)*(num_wimages+1));
			exit(1);
		}
		wimages[num_wimages++]=wi;
	}
	else
	{
		wi=wimages[i];
		wi=RETAIN(wi);
	}

	[aremote setupGetWindowSize: awindow : &x : &y];
	if (x==wi->sx && y==wi->sy && wi->data)
		return wi;

	{
		if (wi->alpha)
		{
			free(wi->alpha);
			wi->alpha=NULL;
			wi->has_alpha=0;
		}
		if (wi->data)
		{
			shmdt(wi->shminfo.shmaddr);
			wi->data=NULL;
		}

//		wi->pending_put=wi->pending_event=0;

		/* TODO: only use shared memory for 'real' on-screen windows */
		wi->shminfo.shmid=shmget(IPC_PRIVATE,DI.bytes_per_pixel*x*y,IPC_CREAT|0700);
		if (!wi->shminfo.shmid==-1)
			NSLog(@"shmget() failed");
/*			printf("shminfo.shmid=%08x  %i bytes (%ix%i)\n",
				wi->shminfo.shmid,wi->ximage->bytes_per_line*wi->ximage->height,
				wi->ximage->width,wi->ximage->height);*/
		wi->shminfo.shmaddr=wi->data=shmat(wi->shminfo.shmid,0,0);
		shmctl(wi->shminfo.shmid,IPC_RMID,0);
//		printf("addr=%p\n",wi->shminfo.shmaddr);
	}

	if (wi->data)
	{
		wi->sx=x;
		wi->sy=y;
		wi->bytes_per_line=DI.bytes_per_pixel*x;
//		wi->bits_per_pixel=DI.bits_per_pixel;
		wi->bytes_per_pixel=DI.bytes_per_pixel;
//		NSLog(@"%@ ximage=%p data=%p\n",wi->ximage,wi->data);

		[wi needsAlpha];
		[aremote setupWindow: wi->window : wi->shminfo.shmid : wi->sx : wi->sy : wi->bytes_per_line];
	}
	else
	{
		NSLog(@"Warning: failed to create shm buffer for window");
		wi->data=NULL;
	}

	return wi;
}

-(void) needsAlpha
{
	if (has_alpha)
		return;

//	NSLog(@"needs alpha for %p: %ix%i",self,sx,sy);

	if (DI.inline_alpha)
	{
		int i;
		unsigned char *s;
		alpha=NULL;
		has_alpha=1;
		/* fill the alpha channel */
		/* TODO: is +=4 correct? but only because the only modes
		with inline alpha are 32 bit */
		for (i=0,s=data+DI.inline_alpha_ofs;i<sx*sy;i++,s+=4)
			*s=0xff;
		return;
	}

	alpha=malloc(sx*sy);
	if (!alpha)
		return;

//	NSLog(@"got buffer at %p",alpha);

	has_alpha=1;
	memset(alpha,0xff,sx*sy);
}

-(void) _gotShmCompletion
{
}

-(void) _exposeRect: (NSRect)r
{
}
@end

#endif


/** ARTGState does all the work **/

@interface ARTGState : GSGState
{
	unsigned char fill_color[4],stroke_color[4];

	float line_width;
	int linecapstyle,linejoinstyle;
	float miter_limit;

	ArtVpathDash dash;
	int do_dash;


	WinImage *wi;

	int clip_x0,clip_y0,clip_x1,clip_y1;
	BOOL all_clipped;
#define CLIP_DATA (wi->data+clip_x0*wi->bytes_per_pixel+clip_y0*wi->bytes_per_line)
	int clip_sx,clip_sy;
}

@end



/* TODO:
this is incorrect. we're supposed to transform when we add the point;
the points in the path shouldn't change if the ctm changes */
@implementation ARTGState (proper_paths)


#if 0
/* useful when debugging */
static void dump_vpath(ArtVpath *vp)
{
	int i;
	for (i=0;;i++)
	{
		if (vp[i].code==ART_MOVETO_OPEN)
			printf("moveto_open");
		else if (vp[i].code==ART_MOVETO)
			printf("moveto");
		else if (vp[i].code==ART_LINETO)
			printf("lineto");
		else
			printf("unknown %i",vp[i].code);

		printf(" (%g %g)\n",vp[i].x,vp[i].y);
		if (vp[i].code==ART_END)
			break;
	}
}
#endif


#define CHECK_PATH do { if (!path) path=[[NSBezierPath alloc] init]; } while (0)

- (void)DPScurrentpoint: (float *)x : (float *)y
{
	NSPoint p;
	if (!path)
		return;
	p=[path currentPoint];
	*x=p.x;
	*y=p.y;
}

- (void) DPSarc: (float)x : (float)y : (float)r : (float)angle1 : (float)angle2 
{
  NSPoint center = NSMakePoint(x, y);

  CHECK_PATH;
  [path appendBezierPathWithArcWithCenter: center
	radius: r
	startAngle: angle1
	endAngle: angle2
	clockwise: NO];
}

- (void) DPSarcn: (float)x : (float)y : (float)r : (float)angle1 : (float)angle2 
{
  NSPoint center = NSMakePoint(x, y);

  CHECK_PATH;
  [path appendBezierPathWithArcWithCenter: center
	radius: r
	startAngle: angle1
	endAngle: angle2
	clockwise: YES];
}

- (void)DPScurveto: (float)x1 : (float)y1 : (float)x2 : (float)y2 : (float)x3 : (float)y3 
{
  NSPoint p1 = NSMakePoint(x1, y1);
  NSPoint p2 = NSMakePoint(x2, y2);
  NSPoint p3 = NSMakePoint(x3, y3);

  CHECK_PATH;
  [path curveToPoint: p3 controlPoint1: p1 controlPoint2: p2];
}

- (void)DPSlineto: (float)x : (float)y 
{
  NSPoint p = NSMakePoint(x, y);

  CHECK_PATH;
  [path lineToPoint: p];
}

- (void)DPSmoveto: (float)x : (float)y 
{
  NSPoint p = NSMakePoint(x, y);

  CHECK_PATH;
  [path moveToPoint: p];
}

- (void)DPSrcurveto: (float)x1 : (float)y1 : (float)x2 : (float)y2 : (float)x3 : (float)y3 
{
  NSPoint p1 = NSMakePoint(x1, y1);
  NSPoint p2 = NSMakePoint(x2, y2);
  NSPoint p3 = NSMakePoint(x3, y3);
 
  CHECK_PATH;
  [path relativeCurveToPoint: p3
	controlPoint1: p1
	controlPoint2: p2];
}

- (void)DPSrlineto: (float)x : (float)y 
{
  NSPoint p = NSMakePoint(x, y);
 
  CHECK_PATH;
  [path relativeLineToPoint: p];
}

- (void)DPSrmoveto: (float)x : (float)y 
{
  NSPoint p = NSMakePoint(x, y);
 
  CHECK_PATH;
  [path relativeMoveToPoint: p];
}

@end



@implementation ARTGState


/* Figure out what blit function we should use. If one or both of the
windows are known to be totally opaque, we can optimize in many ways
(see big table at the end of blit.m). Will set dst_need_alpha and blit_func
if necessary. Returns new operation, op==-1 means noop. */
-(int) _composite_func: (BOOL)src_opaque : (BOOL)src_transparent
	: (BOOL)dst_opaque : (BOOL *)dst_needs_alpha
	: (int)op : (void (**)(composite_run_t *c,int num))blit_func_r
{
	void (*blit_func)(composite_run_t *c,int num);

	*dst_needs_alpha=NO;
	*blit_func_r=blit_func=NULL;

#if 0
	if (src_transparent) /* only happens with compositerect */
	{
	}
	else
#endif
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
			blit_func=DI.composite_plusd_oo;
			break;
		case NSCompositePlusDarker:
			blit_func=DI.composite_plusd_oo;
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
			blit_func=DI.composite_sin_oa;
			break;

		case NSCompositeSourceOut:
		case NSCompositeXOR:
			blit_func=DI.composite_sout_oa;
			break;

		case NSCompositeDestinationOver:
		case NSCompositeDestinationAtop:
			blit_func=DI.composite_dover_oa;
			break;

		case NSCompositeDestinationIn:
			return -1; /* noop */

		case NSCompositeDestinationOut:
			return NSCompositeClear;

		case NSCompositePlusLighter:
			blit_func=DI.composite_plusl_oa;
			break;
		case NSCompositePlusDarker:
			blit_func=DI.composite_plusd_oa;
			break;
		}
	}
	else if (dst_opaque)
	{ /* source has alpha, destination is opaque */
		switch (op)
		{
		case NSCompositeSourceOver:
		case NSCompositeSourceAtop:
			blit_func=DI.composite_sover_ao;
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
			*dst_needs_alpha=YES;
			goto both_have_alpha;

		case NSCompositePlusLighter:
			blit_func=DI.composite_plusl_ao;
			break;
		case NSCompositePlusDarker:
			blit_func=DI.composite_plusd_ao;
			break;
		}
	}
	else
	{ /* both source and destination have alpha */
	both_have_alpha:
		switch (op)
		{
		case NSCompositeSourceOver:
			blit_func=DI.composite_sover_aa;
			break;
		case NSCompositeSourceIn:
			blit_func=DI.composite_sin_aa;
			break;
		case NSCompositeSourceOut:
			blit_func=DI.composite_sout_aa;
			break;
		case NSCompositeSourceAtop:
			blit_func=DI.composite_satop_aa;
			break;
		case NSCompositeDestinationOver:
			blit_func=DI.composite_dover_aa;
			break;
		case NSCompositeDestinationIn:
			blit_func=DI.composite_din_aa;
			break;
		case NSCompositeDestinationOut:
			blit_func=DI.composite_dout_aa;
			break;
		case NSCompositeDestinationAtop:
			blit_func=DI.composite_datop_aa;
			break;
		case NSCompositeXOR:
			blit_func=DI.composite_xor_aa;
			break;
		case NSCompositePlusLighter:
			blit_func=DI.composite_plusl_aa;
			break;
		case NSCompositePlusDarker:
			blit_func=DI.composite_plusd_aa;
			break;
		}
	}
	*blit_func_r=blit_func;
	return op;
}



- (void) compositeGState: (GSGState *)source
                fromRect: (NSRect)aRect
                 toPoint: (NSPoint)aPoint
                      op: (NSCompositingOperation)op
{
	ARTGState *ags=(ARTGState *)source;
	NSRect sr,dr;
	unsigned char *dst,*dst_alpha,*src,*src_alpha;

	void (*blit_func)(composite_run_t *c,int num)=NULL;

	int sx,sy;
	int x0,y0,x1,y1;

	int sbpl,dbpl;
	int asbpl,adbpl;

	/* 0=top->down, 1=bottom->up */
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

//	NSLog(@"op=%i  %i %i\n",op,ags->wi->has_alpha,wi->has_alpha);


	{
		BOOL dst_needs_alpha;
		op=[self _composite_func: !ags->wi->has_alpha : NO
			: !wi->has_alpha : &dst_needs_alpha
			: op : &blit_func];
		if (op==-1)
			return;

		if (dst_needs_alpha)
		{
			[wi needsAlpha];
			if (!wi->has_alpha)
				return;
		}
	}


//	NSLog(@" got %i %08x",op,blit_func);

	/* these ignore the source window, so we send them off to
	compositerect: op: */
	if (op==NSCompositeClear || op==NSCompositeHighlight)
	{
		[self compositerect: NSMakeRect(aPoint.x,aPoint.y,
				aRect.size.width,aRect.size.height)
			op: op];
		return;
	}

/*	NSLog(@"compositeGState: %p fromRect: (%g %g)+(%g %g)  toPoint: (%g %g)  op: %i",
		source,
		aRect.origin.x,aRect.origin.y,
		aRect.size.width,aRect.size.height,
		aPoint.x,aPoint.y,
		op);*/

/*	NSLog(@"composite op=%i  from %p %ix%i to %p %ix%i\n",
		op,ags,ags->wi->sx,ags->wi->sy,
		wi,wi->sx,wi->sy);*/

//	printf("src->wi=%ix%i  dst->wi=%ix%i\n",ags->wi->sx,ags->wi->sy,wi->sx,wi->sy);


	/* Set up all the pointers and clip things */

	dbpl=wi->bytes_per_line;
	sbpl=ags->wi->bytes_per_line;

	sr=aRect;
	sr=[ags->ctm rectInMatrixSpace: sr];
/*	printf("sr=(%g %g)+(%g %g)\n",
		sr.origin.x,sr.origin.y,
		sr.size.width,sr.size.height);*/
	sr.origin.y=ags->wi->sy-sr.origin.y-sr.size.height;
	sx=sr.origin.x;
	sy=sr.origin.y;

	dr=aRect;
	dr.origin=aPoint;
	dr=[ctm rectInMatrixSpace: dr];
/*	printf("dr=(%g %g)+(%g %g)\n",
		dr.origin.x,dr.origin.y,
		dr.size.width,dr.size.height);*/
	dr.origin.y=wi->sy-dr.origin.y-dr.size.height;
//	printf("%g=%i-y-%g\n",dr.origin.y,sy,dr.size.height);

	x0=dr.origin.x;
	y0=dr.origin.y;
	x1=dr.origin.x+dr.size.width;
	y1=dr.origin.y+dr.size.height;

//	printf("s=(%i %i)  (%i %i)-(%i %i)\n",sx,sy,x0,y0,x1,y1);

//	printf("clip=(%i %i)-(%i %i)\n",clip_x0,clip_y0,clip_x1,clip_y1);
	if (clip_x0>x0)
	{
		sx+=clip_x0-x0;
		x0=clip_x0;
	}
	if (clip_y0>y0)
	{
		sy+=clip_y0-y0;
		y0=clip_y0;
	}

	if (x1>clip_x1)
		x1=clip_x1;
	if (y1>clip_y1)
		y1=clip_y1;

	if (x0>=x1 || y0>=y1) return;

	/* TODO: clip source? how?
 	we should at least clip the source to the source window to avoid
	crashes */

//	printf("clipped s=(%i %i)  (%i %i)-(%i %i)\n",sx,sy,x0,y0,x1,y1);

	dst=wi->data+x0*DI.bytes_per_pixel+y0*dbpl;
	src=ags->wi->data+sx*DI.bytes_per_pixel+sy*sbpl;

	if (ags->wi->has_alpha && op==NSCompositeCopy)
	{
		[wi needsAlpha];
		if (!wi->has_alpha)
			return;
	}

	if (ags->wi->has_alpha)
	{
		if (DI.inline_alpha)
			src_alpha=src;
		else
			src_alpha=ags->wi->alpha+sx+sy*ags->wi->sx;
		asbpl=ags->wi->sx;
	}
	else
	{
		src_alpha=NULL;
		asbpl=0;
	}

	if (wi->has_alpha)
	{
		if (DI.inline_alpha)
			dst_alpha=dst;
		else
			dst_alpha=wi->alpha+x0+y0*wi->sx;
		adbpl=wi->sx;
	}
	else
	{
		dst_alpha=NULL;
		adbpl=0;
	}

	y1-=y0;
	x1-=x0;

//	printf("fixed %p -> %p s=(%i %i)  (%i %i)-(%i %i)\n",src,dst,sx,sy,x0,y0,x1,y1);

	/* To handle overlapping areas properly, we sometimes need to do
	things bottom-up instead of top-down. If so, we flip the
	coordinates here. */
	order=0;
	if (ags==self && sy<=y0)
	{
		order=1;
		dst+=dbpl*(y1-1);
		src+=sbpl*(y1-1);
		dst_alpha+=adbpl*(y1-1);
		src_alpha+=asbpl*(y1-1);
		dbpl=-dbpl;
		sbpl=-sbpl;
		adbpl=-adbpl;
		asbpl=-asbpl;
		if (sy==y0)
		{ /* TODO: pure horizontal, not handled properly in all
		     cases */
			if ((sx>=x0 && sx<=x0+x1) || (x0>=sx && x0<=x0+x1))
				order=2;
		}
	}

	if (op==NSCompositeCopy)
	{ /* TODO: for inline alpha, make sure even opaque destinations have
	     alpha properly filled in */
		int y;

		if (!DI.inline_alpha && wi->has_alpha)
		{
			if (ags->wi->has_alpha)
				for (y=0;y<y1;y++,dst_alpha+=adbpl,src_alpha+=asbpl)
					memmove(dst_alpha,src_alpha,x1);
			else
				for (y=0;y<y1;y++,dst_alpha+=adbpl)
					memset(dst_alpha,0xff,x1);
		}

		x1*=DI.bytes_per_pixel;
		for (y=0;y<y1;y++,dst+=dbpl,src+=sbpl)
			memmove(dst,src,x1);
		/* TODO: worth the complexity? */
/*		{
			int y;
			x1*=DI.bytes_per_pixel;
			for (y=0;y<y1;y++,dst+=dbpl,src+=sbpl)
				memcpy(dst,src,x1);
		}*/
		return;
	}


	if (!blit_func)
	{
		NSLog(@"unimplemented: compositeGState: %p fromRect: (%g %g)+(%g %g) toPoint: (%g %g)  op: %i",
			source,
			aRect.origin.x,aRect.origin.y,
			aRect.size.width,aRect.size.height,
			aPoint.x,aPoint.y,
			op);
		return;
	}

	/* this breaks the alpha pointer in some, but that's ok since in
	all those cases, the alpha pointer isn't used (inline alpha or
 	no alpha) */
	if (order==2)
	{
		unsigned char tmpbuf[x1*DI.bytes_per_pixel];
		int y;
		composite_run_t c;

		c.dst=dst;
		c.dsta=dst_alpha;
		c.src=src;
		c.srca=src_alpha;
		for (y=0;y<y1;y++,c.dst+=dbpl,c.src+=sbpl)
		{
			/* don't need to copy alpha since it is either
			separate and won't be written to or part of the
			data */
			/* TODO: this only holds if there's no destination
			alpha, which is no longer true. ignore for now; why
			would someone sourceover something on itself? */
			memcpy(tmpbuf,src,x1*DI.bytes_per_pixel);
			blit_func(&c,x1);
			c.srca+=asbpl;
			c.dsta+=adbpl;
		}
	}
	else
	{
		int y;
		composite_run_t c;

		c.dst=dst;
		c.dsta=dst_alpha;
		c.src=src;
		c.srca=src_alpha;
		for (y=0;y<y1;y++,c.dst+=dbpl,c.src+=sbpl)
		{
			blit_func(&c,x1);
			c.srca+=asbpl;
			c.dsta+=adbpl;
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
		aRect.origin.x,aRect.origin.y,aRect.size.width,aRect.size.height,
		aPoint.x,aPoint.y,delta);
}

- (void) compositerect: (NSRect)aRect
                    op: (NSCompositingOperation)op
{
/* much setup code shared with compositeGState:... */
	NSRect dr;
	unsigned char *dst;

	int x0,y0,x1,y1;

	int dbpl;

	void (*blit_func)(composite_run_t *c,int num);


	if (!wi || !wi->data) return;
	if (all_clipped) return;

	dbpl=wi->bytes_per_line;

	dr=aRect;
	dr=[ctm rectInMatrixSpace: dr];
	dr.origin.y=wi->sy-dr.origin.y-dr.size.height;

	x0=dr.origin.x;
	y0=dr.origin.y;
	x1=dr.origin.x+dr.size.width;
	y1=dr.origin.y+dr.size.height;

	if (clip_x0>x0)
		x0=clip_x0;
	if (clip_y0>y0)
		y0=clip_y0;

	if (x1>clip_x1)
		x1=clip_x1;
	if (y1>clip_y1)
		y1=clip_y1;

	if (x0>=x1 || y0>=y1) return;

	dst=wi->data+x0*DI.bytes_per_pixel+y0*dbpl;

	y1-=y0;
	x1-=x0;

	{
		BOOL dest_needs_alpha;

		/* TODO: which color? using fill_color for now */
		op=[self _composite_func: fill_color[3]==255 : fill_color[3]==0
			: !wi->has_alpha : &dest_needs_alpha
			: op : &blit_func];

		if (op==-1)
			return;

		if (dest_needs_alpha)
		{
			[wi needsAlpha];
			if (!wi->has_alpha)
				return;
		}
	}

	if (op==NSCompositeClear)
	{
		int y;
		[wi needsAlpha];
		if (!wi->has_alpha)
			return;
		if (!DI.inline_alpha)
		{
			unsigned char *dsta;
			dsta=wi->alpha+x0+y0*wi->sx;
			for (y=0;y<y1;y++,dsta+=wi->sx)
				memset(dsta,0,x1);
		}
		x1*=DI.bytes_per_pixel;
		for (y=0;y<y1;y++,dst+=dbpl)
			memset(dst,0,x1);
		return;
	}
	else if (op==NSCompositeHighlight)
	{
		int y,n;
		/* This must be reversible, which limits what we can
		do. */
		x1*=DI.bytes_per_pixel;
		for (y=0;y<y1;y++,dst+=dbpl)
		{
			unsigned char *d=dst;
			for (n=x1;n;n--,d++)
				(*d)^=0xff;
		}
		return;
	}
	else if (op==NSCompositeCopy)
	{
		render_run_t ri;
		int y;
		ri.dst=dst;
		/* We don't want to blend, so we premultiply and fill the
		alpha channel manually. */
		ri.a=fill_color[3];
		ri.r=(fill_color[0]*ri.a+0xff)>>8;
		ri.g=(fill_color[1]*ri.a+0xff)>>8;
		ri.b=(fill_color[2]*ri.a+0xff)>>8;
		for (y=0;y<y1;y++,ri.dst+=dbpl)
			DI.render_run_opaque(&ri,x1);
		if (wi->has_alpha)
		{
			if (DI.inline_alpha)
			{
				int n;
				unsigned char *p;
				for (y=0;y<y1;y++,dst+=dbpl)
				{ /* TODO: needs to change to support inline
				alpha for non-32-bit modes */
					for (p=dst,n=x1;n;n--,p+=4)
						dst[DI.inline_alpha_ofs]=ri.a;
				}
			}
			else
			{
				unsigned char *dsta;
				dsta=wi->alpha+x0+y0*wi->sx;
				for (y=0;y<y1;y++,dsta+=wi->sx)
					memset(dsta,ri.a,x1);
			}
		}
		return;
	}
	else if (blit_func)
	{
		/* this is slightly ugly, but efficient */
		unsigned char buf[DI.bytes_per_pixel*x1];
		unsigned char abuf[fill_color[3]==255?1:x1];
		int y;
		composite_run_t c;

		c.src=buf;
		if (fill_color[3]!=255)
			c.srca=abuf;
		else
			c.srca=NULL;
		c.dst=dst;
		if (wi->has_alpha)
			c.dsta=wi->alpha+x0+y0*wi->sx;
		else
			c.dsta=NULL;

		{
			render_run_t ri;
			ri.dst=buf;
			ri.dsta=NULL;
			/* Note that we premultiply _here_ and set the alpha
			channel manually (for speed; no reason to do slow
			blending when we just want a straight blit of all
			channels). */
			ri.a=fill_color[3];
			ri.r=(fill_color[0]*ri.a+0xff)>>8;
			ri.g=(fill_color[1]*ri.a+0xff)>>8;
			ri.b=(fill_color[2]*ri.a+0xff)>>8;
			DI.render_run_opaque(&ri,x1);
			if (fill_color[3]!=255)
				memset(abuf,ri.a,x1);
		}

		for (y=0;y<y1;y++,c.dst+=dbpl,c.dsta+=wi->sx)
			blit_func(&c,x1);
		return;
	}

	NSLog(@"unimplemented compositerect: (%g %g)+(%g %g)  op: %i",
		aRect.origin.x,aRect.origin.y,
		aRect.size.width,aRect.size.height,
		op);
}


/* TODO:
optimize all this. passing device_color_t structures around by value is
very expensive
*/
-(void) setColor: (device_color_t)color  state: (color_state_t)cState
{
	device_color_t c;
	[super setColor: color  state: cState];
	if (cState&(COLOR_FILL|COLOR_STROKE))
	{
		c=gsColorToRGB(fillColor);
		if (c.field[0]>1.0) c.field[0]=1.0;
		if (c.field[0]<0.0) c.field[0]=0.0;
		c.field[0]*=255;
		if (c.field[1]>1.0) c.field[1]=1.0;
		if (c.field[1]<0.0) c.field[1]=0.0;
		c.field[1]*=255;
		if (c.field[2]>1.0) c.field[2]=1.0;
		if (c.field[2]<0.0) c.field[2]=0.0;
		c.field[2]*=255;
	}

	if (cState&COLOR_FILL)
	{
		fill_color[0]=c.field[0];
		fill_color[1]=c.field[1];
		fill_color[2]=c.field[2];
		fill_color[3]=fillColor.field[AINDEX]*255;
	}
	if (cState&COLOR_STROKE)
	{
		stroke_color[0]=c.field[0];
		stroke_color[1]=c.field[1];
		stroke_color[2]=c.field[2];
		stroke_color[3]=strokeColor.field[AINDEX]*255;
	}
}

/* TODO: optimize the others? optimize the gsc code instead? */
- (void) DPSsetgray: (float)gray
{
  if (gray < 0.0) gray = 0.0;
  if (gray > 1.0) gray = 1.0;

  fillColor.space = strokeColor.space = gray_colorspace;
  fillColor.field[0] = strokeColor.field[0] = gray;
  cstate = COLOR_FILL|COLOR_STROKE;

  stroke_color[0] = stroke_color[1] = stroke_color[2] =
    fill_color[0] = fill_color[1] = fill_color[2] = gray*255;
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
	p=[path currentPoint];

	[(id<FTFontInfo>)[font fontInfo]
		outlineString: s
		at: p.x:p.y
		gstate: self];
	[self DPSclosepath];
}

- (void) DPSshow: (const char*)s
{
	NSPoint p;
	int x,y;

	if (!wi || !wi->data) return;
	if (all_clipped)
		return;

	if ([path isEmpty]) return;
	p=[path currentPoint];
	p=[ctm pointInMatrixSpace: p];

	x=p.x;
	y=wi->sy-p.y;
	[(id<FTFontInfo>)[font fontInfo]
		drawString: s
		at: x:y
		to: clip_x0:clip_y0:clip_x1:clip_y1:CLIP_DATA:wi->bytes_per_line
		color: fill_color[0]:fill_color[1]:fill_color[2]:fill_color[3]
		transform: ctm
		drawinfo: &DI];
}

- (void) DPSwidthshow: (float)x : (float)y : (int)c : (const char*)s
{ /* TODO: add (x,y) user-space to the character c's advancement */
	NSLog(@"ignoring DPSwidthshow: %g : %g : %i : '%s'",x,y,c,s);
}

- (void) DPSxshow: (const char*)s : (const float*)numarray : (int)size
{
	NSPoint p;
	int x,y;

	if (!wi || !wi->data) return;
	if (all_clipped)
		return;

	if ([path isEmpty]) return;
	p=[path currentPoint];
	p=[ctm pointInMatrixSpace: p];

	x=p.x;
	y=wi->sy-p.y;
	[(id<FTFontInfo>)[font fontInfo]
		drawString: s
		at: x:y
		to: clip_x0:clip_y0:clip_x1:clip_y1:CLIP_DATA:wi->bytes_per_line
		color: fill_color[0]:fill_color[1]:fill_color[2]:fill_color[3]
		transform: ctm
		deltas: numarray : size : 1];
}

- (void) DPSxyshow: (const char*)s : (const float*)numarray : (int)size
{
	NSPoint p;
	int x,y;

	if (!wi || !wi->data) return;
	if (all_clipped)
		return;

	if ([path isEmpty]) return;
	p=[path currentPoint];
	p=[ctm pointInMatrixSpace: p];

	x=p.x;
	y=wi->sy-p.y;
	[(id<FTFontInfo>)[font fontInfo]
		drawString: s
		at: x:y
		to: clip_x0:clip_y0:clip_x1:clip_y1:CLIP_DATA:wi->bytes_per_line
		color: fill_color[0]:fill_color[1]:fill_color[2]:fill_color[3]
		transform: ctm
		deltas: numarray : size : 3];
}

- (void) DPSyshow: (const char*)s : (const float*)numarray : (int)size
{
	NSPoint p;
	int x,y;

	if (!wi || !wi->data) return;
	if (all_clipped)
		return;

	if ([path isEmpty]) return;
	p=[path currentPoint];
	p=[ctm pointInMatrixSpace: p];

	x=p.x;
	y=wi->sy-p.y;
	[(id<FTFontInfo>)[font fontInfo]
		drawString: s
		at: x:y
		to: clip_x0:clip_y0:clip_x1:clip_y1:CLIP_DATA:wi->bytes_per_line
		color: fill_color[0]:fill_color[1]:fill_color[2]:fill_color[3]
		transform: ctm
		deltas: numarray : size : 2];
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


- (void)DPSarct: (float)x1 : (float)y1 : (float)x2 : (float)y2 : (float)r
{
	float x0,y0;
	float dx1,dy1,dx2,dy2;
	float l,a1,a2;
	NSPoint p;

	p=[path currentPoint];
	x0=p.x;
	y0=p.y;

	dx1=x0-x1;
	dy1=y0-y1;
	dx2=x2-x1;
	dy2=y2-y1;

	l=dx1*dx1+dy1*dy1;
	if (l<=0)
	{
		[self DPSlineto: x1 : y1];
		return;
	}
	l=1/sqrt(l);
	dx1*=l; dy1*=l;

	l=dx2*dx2+dy2*dy2;
	if (l<=0)
	{
		[self DPSlineto: x1 : y1];
		return;
	}
	l=1/sqrt(l);
	dx2*=l; dy2*=l;

	l=dx1*dx2+dy1*dy2;
	if (l<-0.999)
	{
		[self DPSlineto: x1 : y1];
		return;
	}

	l=r/sin(acos(l));

	p.x=x1+(dx1+dx2)*l;
	p.y=y1+(dy1+dy2)*l;

	l=dx1*dy2-dx2*dy1;

	a1=acos(dx1)/PI*180;
	if (dy1<0) a1=-a1;
	a2=acos(dx2)/PI*180;
	if (dy2<0) a2=-a2;

	if (l<0)
	{
		a2=a2-90;
		a1=a1+90;
		[self DPSarc: p.x:p.y : r : a1 : a2];
	}
	else
	{
		a2=a2+90;
		a1=a1-90;
		[self DPSarcn: p.x:p.y : r : a1 : a2];
	}
}


- (void) DPSclip
{
	NSLog(@"ignoring DPSclip");
}

- (void) DPSeoclip
{
	NSLog(@"ignoring DPSeoclip");
}



-(void) _fill: (int)rule
{
	ArtBpath *bpath,*bp2;
	ArtVpath *vp;
	ArtSVP *svp;
	int i,j,c,cur_start,cur_line;
	NSPoint points[3];
	NSBezierPathElement t;
	double matrix[6];

	if (!wi || !wi->data) return;
	if (all_clipped) return;
	if (!fill_color[3]) return;

	c=[path elementCount];
	if (!c) return;
	/* TODO: double-check upper bound on size */
	bpath=art_new(ArtBpath,2*c+1);
	cur_start=-1;
	cur_line=0;
	for (i=j=0;i<c;i++)
	{
		t=[path elementAtIndex: i associatedPoints: points];
		switch (t)
		{
		case NSMoveToBezierPathElement:
			if (cur_start!=-1 && cur_line)
			{
				if (bpath[j-1].x3!=bpath[cur_start].x3 ||
				    bpath[j-1].y3!=bpath[cur_start].y3)
				{
					bpath[j].x3=bpath[cur_start].x3;
					bpath[j].y3=bpath[cur_start].y3;
					bpath[j].code=ART_LINETO;
					j++;
				}
			}
			bpath[j].code=ART_MOVETO;
			bpath[j].x3=points[0].x;
			bpath[j].y3=points[0].y;
			cur_start=j;
			j++;
			cur_line=0;
			break;

		case NSLineToBezierPathElement:
			cur_line++;
			bpath[j].code=ART_LINETO;
			bpath[j].x3=points[0].x;
			bpath[j].y3=points[0].y;
			j++;
			break;

		case NSCurveToBezierPathElement:
			cur_line++;
			bpath[j].code=ART_CURVETO;
			bpath[j].x1=points[0].x;
			bpath[j].y1=points[0].y;
			bpath[j].x2=points[1].x;
			bpath[j].y2=points[1].y;
			bpath[j].x3=points[2].x;
			bpath[j].y3=points[2].y;
			j++;
			break;

		case NSClosePathBezierPathElement:
			break;

		default:
			NSLog(@"invalid type %i\n",t);
			art_free(bpath);
			return;
		}
	}
	if (cur_start!=-1 && cur_line)
	{
		if (bpath[j-1].x3!=bpath[cur_start].x3 ||
		    bpath[j-1].y3!=bpath[cur_start].y3)
		{
			bpath[j].x3=bpath[cur_start].x3;
			bpath[j].y3=bpath[cur_start].y3;
			bpath[j].code=ART_LINETO;
			j++;
		}
	}
	bpath[j].code=ART_END;

	matrix[0]=ctm->matrix.m11;
	matrix[1]=-ctm->matrix.m12;
	matrix[2]=ctm->matrix.m21;
	matrix[3]=-ctm->matrix.m22;
	matrix[4]=ctm->matrix.tx;
	matrix[5]=-ctm->matrix.ty+wi->sy;

	bp2=art_bpath_affine_transform(bpath,matrix);
	art_free(bpath);
	bpath=bp2;

	vp=art_bez_path_to_vec(bpath,0.5);
	art_free(bpath);

	svp=art_svp_from_vpath(vp);
	art_free(vp);

	{
		ArtSVP *svp2;
		ArtSvpWriter *svpw;

		svpw=art_svp_writer_rewind_new(rule);
		art_svp_intersector(svp,svpw);
		svp2=art_svp_writer_rewind_reap(svpw);
		art_svp_free(svp);
		svp=svp2;
	}


	artcontext_render_svp(svp,clip_x0,clip_y0,clip_x1,clip_y1,
		fill_color[0],fill_color[1],fill_color[2],fill_color[3],
		CLIP_DATA,wi->bytes_per_line,
		wi->has_alpha?wi->alpha+clip_x0+clip_y0*wi->sx:NULL,wi->sx,
		wi->has_alpha,
		&DI);

	art_svp_free(svp);

	[path removeAllPoints];
}

- (void) DPSeofill
{
	[self _fill: ART_WIND_RULE_ODDEVEN];
}

- (void) DPSfill
{
	[self _fill: ART_WIND_RULE_NONZERO];
}


- (void) DPSinitclip;
{ /* TODO: try all this again with reversed paths */
	if (!wi)
	{
		all_clipped=YES;
		return;
	}

	clip_x0=clip_y0=0;
	clip_x1=wi->sx;
	clip_y1=wi->sy;
	all_clipped=NO;
	clip_sx=clip_x1-clip_x0;
	clip_sy=clip_y1-clip_y0;
}

- (void) DPSrectclip: (float)x : (float)y : (float)w : (float)h
{
	NSPoint p;
	NSSize s;
	NSRect r;

	if (all_clipped)
		return;

	if (!wi)
	{
		all_clipped=YES;
		return;
	}

	r=[ctm rectInMatrixSpace: NSMakeRect(x,y,w,h)];

	p=r.origin;
	s=r.size;

	p.y=wi->sy-p.y;
	p.y-=s.height;

/*	printf("%p clip was (%i %i)-(%i %i)  (%g %g)+(%g %g)  -> (%g %g)+(%g %g)\n",
		self,
		clip_x0,clip_y0,clip_x1,clip_y1,
		x,y,w,h,p.x,p.y,s.width,s.height);*/

	if (p.x>clip_x0)
		clip_x0=p.x;
	if (p.y>clip_y0)
		clip_y0=p.y;

	p.x+=s.width;
	p.y+=s.height;
	if (p.x<clip_x1)
		clip_x1=p.x;
	if (p.y<clip_y1)
		clip_y1=p.y;

	if (clip_x0>=clip_x1 || clip_y0>=clip_y1)
	{
//		printf("%p all_clipped by (%g %g)+(%g %g)\n",self,x,y,w,h);
		all_clipped=YES;
	}

	clip_sx=clip_x1-clip_x0;
	clip_sy=clip_y1-clip_y0;

//	printf("now %i (%i %i)-(%i %i)\n",all_clipped,clip_x0,clip_y0,clip_x1,clip_y1);
}

- (void) DPSrectfill: (float)x : (float)y : (float)w : (float)h
{
	ArtVpath vp[6];
	ArtSVP *svp;
	float matrix[6];
	float det;
	int i;
	int x0,y0,x1,y1,t;

	if (!wi || !wi->data) return;
	if (all_clipped) return;
	if (!fill_color[3]) return;

	if (w<0) x+=w,w=-w;
	if (h<0) y+=h,h=-h;

	matrix[0]= ctm->matrix.m11;
	matrix[1]=-ctm->matrix.m12;
	matrix[2]= ctm->matrix.m21;
	matrix[3]=-ctm->matrix.m22;
	matrix[4]= ctm->matrix.tx;
	matrix[5]=-ctm->matrix.ty+wi->sy;

	/* If the matrix is 'inverted', ie. if the determinant is negative,
	we need to flip the order of the vertices. Since it's a rectangle
	we can just swap vertex 1 and 3. */
	det=matrix[0]*matrix[3]-matrix[1]*matrix[2];

	vp[0].code=ART_MOVETO;
	vp[0].x=x*matrix[0]+y*matrix[2]+matrix[4];
	vp[0].y=x*matrix[1]+y*matrix[3]+matrix[5];

	i=det>0?3:1;
	vp[i].code=ART_LINETO;
	vp[i].x=vp[0].x+w*matrix[0];
	vp[i].y=vp[0].y+w*matrix[1];

	vp[2].code=ART_LINETO;
	vp[2].x=vp[0].x+w*matrix[0]+h*matrix[2];
	vp[2].y=vp[0].y+w*matrix[1]+h*matrix[3];

	i^=2;
	vp[i].code=ART_LINETO;
	vp[i].x=vp[0].x+h*matrix[2];
	vp[i].y=vp[0].y+h*matrix[3];

	vp[4].code=ART_LINETO;
	vp[4].x=vp[0].x;
	vp[4].y=vp[0].y;

	vp[5].code=ART_END;
	vp[5].x=vp[5].y=0;

	/* Check if this rectangle is axis-aligned and on whole pixel
	boundaries. */
	x0=vp[0].x+0.5;
	x1=vp[2].x+0.5;
	y0=vp[0].y+0.5;
	y1=vp[2].y+0.5;
	if (fabs(vp[0].x-vp[1].x)<0.01 && fabs(vp[1].y-vp[2].y)<0.01 &&
	    fabs(vp[0].x-x0)<0.01 && fabs(vp[0].y-y0)<0.01 &&
	    fabs(vp[2].x-x1)<0.01 && fabs(vp[2].y-y1)<0.01)
	{
	}
	else if (fabs(vp[0].y-vp[1].y)<0.01 && fabs(vp[1].x-vp[2].x)<0.01 &&
	         fabs(vp[0].x-x0)<0.01 && fabs(vp[0].y-y0)<0.01 &&
	         fabs(vp[2].x-x1)<0.01 && fabs(vp[2].y-y1)<0.01)
	{
	}
	else
	{
		svp=art_svp_from_vpath(vp);

		artcontext_render_svp(svp,clip_x0,clip_y0,clip_x1,clip_y1,
			fill_color[0],fill_color[1],fill_color[2],fill_color[3],
			CLIP_DATA,wi->bytes_per_line,
			wi->has_alpha?wi->alpha+clip_x0+clip_y0*wi->sx:NULL,wi->sx,
			wi->has_alpha,
			&DI);

		art_svp_free(svp);
		return;
	}

	/* optimize axis- and pixel-aligned rectangles */
	{
		unsigned char *dst=CLIP_DATA;
		render_run_t ri;

		if (x0>x1) t=x1,x1=x0,x0=t;
		x0-=clip_x0;
		x1-=clip_x0;
		if (x0<=0)
			x0=0;
		else
			dst+=x0*DI.bytes_per_pixel;
		if (x1>clip_sx) x1=clip_sx;

		x1-=x0;
		if (x1<=0)
			return;

		if (y0>y1) t=y1,y1=y0,y0=t;
		y0-=clip_y0;
		y1-=clip_y0;
		if (y0<=0)
			y0=0;
		else
			dst+=y0*wi->bytes_per_line;
		if (y1>clip_sy) y1=clip_sy;

		if (y1<=y0)
			return;

		ri.dst=dst;
		ri.r=fill_color[0];
		ri.g=fill_color[1];
		ri.b=fill_color[2];
		ri.a=fill_color[3];
		if (wi->has_alpha)
		{
			ri.dsta=wi->alpha+x0+y0*wi->sx;

			if (fill_color[3]==255)
			{
				for (;y0<y1;y0++,ri.dst+=wi->bytes_per_line,ri.dsta+=wi->sx)
					RENDER_RUN_OPAQUE_A(&ri,x1);
			}
			else
			{
				for (;y0<y1;y0++,ri.dst+=wi->bytes_per_line,ri.dsta+=wi->sx)
					RENDER_RUN_ALPHA_A(&ri,x1);
			}
		}
		else
		{
			if (fill_color[3]==255)
			{
				for (;y0<y1;y0++,ri.dst+=wi->bytes_per_line)
					RENDER_RUN_OPAQUE(&ri,x1);
			}
			else
			{
				for (;y0<y1;y0++,ri.dst+=wi->bytes_per_line)
					RENDER_RUN_ALPHA(&ri,x1);
			}
		}
	}
}

- (void) DPSrectstroke: (float)x : (float)y : (float)w : (float)h
{
	ArtVpath *vp,*vp2;
	ArtSVP *svp;
	double matrix[6];
	double temp_scale;

	if (!wi || !wi->data) return;
	if (all_clipped) return;
	if (!stroke_color[3]) return;

	vp=art_new(ArtVpath,6);

	if (line_width==(int)line_width && ((int)line_width)&1)
	{ /* TODO: only do this if stroke-adjust is on? */
	/* TODO: check coordinates to see how much we should adjust */
		x+=0.5;
		y+=0.5;
		w-=1;
		h-=1;
	}

	vp[0].code=ART_MOVETO;
	vp[0].x=x; vp[0].y=y;

	vp[1].code=ART_LINETO;
	vp[1].x=x+w; vp[1].y=y;

	vp[2].code=ART_LINETO;
	vp[2].x=x+w; vp[2].y=y+h;

	vp[3].code=ART_LINETO;
	vp[3].x=x; vp[3].y=y+h;

	vp[4].code=ART_LINETO;
	vp[4].x=x; vp[4].y=y;

	vp[5].code=ART_END;
	vp[5].x=vp[5].y=0;

	matrix[0]=ctm->matrix.m11;
	matrix[1]=-ctm->matrix.m12;
	matrix[2]=ctm->matrix.m21;
	matrix[3]=-ctm->matrix.m22;
	matrix[4]=ctm->matrix.tx;
	matrix[5]=-ctm->matrix.ty+wi->sy;

	/* TODO: this is a hack, but it's better than nothing */
	temp_scale=sqrt(fabs(matrix[0]*matrix[3]-matrix[1]*matrix[2]));
	if (temp_scale<=0) temp_scale=1;

	vp2=art_vpath_affine_transform(vp,matrix);
	art_free(vp);
	vp=vp2;

	if (do_dash)
	{
		/* try to adjust the offset so dashes appear on pixel boundaries
		(otherwise it turns into an antialiased blur) */
		int i;

		dash.offset+=(((int)line_width)&1)/2.0;

		for (i=0;i<dash.n_dash;i++)
			dash.dash[i]*=temp_scale;
		dash.offset*=temp_scale;
		vp2=art_vpath_dash(vp,&dash);
		dash.offset/=temp_scale;
		for (i=0;i<dash.n_dash;i++)
			dash.dash[i]/=temp_scale;
		art_free(vp);
		vp=vp2;

		dash.offset-=(((int)line_width)&1)/2.0;
	}

	svp=art_svp_vpath_stroke(vp,linejoinstyle,linecapstyle,temp_scale*line_width,miter_limit,0.5);
	art_free(vp);

	artcontext_render_svp(svp,clip_x0,clip_y0,clip_x1,clip_y1,
		stroke_color[0],stroke_color[1],stroke_color[2],stroke_color[3],
		CLIP_DATA,wi->bytes_per_line,
		wi->has_alpha?wi->alpha+clip_x0+clip_y0*wi->sx:NULL,wi->sx,
		wi->has_alpha,
		&DI);

	art_svp_free(svp);
}

- (void) DPSstroke;
{
/* TODO: resolve line-width and dash scaling issues */
	ArtBpath *bpath,*bp2;
	ArtVpath *vp;
	ArtSVP *svp;
	int i,j,c,last_subpath;
	NSPoint points[3];
	NSBezierPathElement t;
	double matrix[6];
	double temp_scale;

	if (!wi || !wi->data) return;
	if (all_clipped) return;
	if (!stroke_color[3]) return;

	c=[path elementCount];
	if (!c) return;
	bpath=art_new(ArtBpath,c+1);
	last_subpath=-1;
	j=0;
	for (i=0;i<c;i++)
	{
		t=[path elementAtIndex: i associatedPoints: points];
		switch (t)
		{
		case NSMoveToBezierPathElement:
			bpath[j].code=ART_MOVETO_OPEN;
			bpath[j].x3=points[0].x;
			bpath[j].y3=points[0].y;
			last_subpath=j;
			j++;
			break;

		case NSLineToBezierPathElement:
			bpath[j].code=ART_LINETO;
			bpath[j].x3=points[0].x;
			bpath[j].y3=points[0].y;
			j++;
			break;

		case NSCurveToBezierPathElement:
			bpath[j].code=ART_CURVETO;
			bpath[j].x1=points[0].x;
			bpath[j].y1=points[0].y;
			bpath[j].x2=points[1].x;
			bpath[j].y2=points[1].y;
			bpath[j].x3=points[2].x;
			bpath[j].y3=points[2].y;
			j++;
			break;

		case NSClosePathBezierPathElement:
			if (last_subpath!=-1)
			{
				bpath[last_subpath].code=ART_MOVETO;
				bpath[j].code=ART_LINETO;
				bpath[j].x3=bpath[last_subpath].x3;
				bpath[j].y3=bpath[last_subpath].y3;
				j++;
			}
			break;

		default:
			NSLog(@"invalid type %i\n",t);
			art_free(bpath);
			return;
		}
	}
	bpath[j].code=ART_END;

	matrix[0]=ctm->matrix.m11;
	matrix[1]=-ctm->matrix.m12;
	matrix[2]=ctm->matrix.m21;
	matrix[3]=-ctm->matrix.m22;
	matrix[4]=ctm->matrix.tx;
	matrix[5]=-ctm->matrix.ty+wi->sy;

	/* TODO: this is a hack, but it's better than nothing */
	temp_scale=sqrt(fabs(matrix[0]*matrix[3]-matrix[1]*matrix[2]));
	if (temp_scale<=0) temp_scale=1;

	/* TODO: this is wrong. we should transform _after_ we dash and
	stroke */
	bp2=art_bpath_affine_transform(bpath,matrix);
	art_free(bpath);
	bpath=bp2;

	vp=art_bez_path_to_vec(bpath,0.5);
	art_free(bpath);

	if (do_dash)
	{
		ArtVpath *vp2;
		int i;
		for (i=0;i<dash.n_dash;i++)
			dash.dash[i]*=temp_scale;
		dash.offset*=temp_scale;
		vp2=art_vpath_dash(vp,&dash);
		dash.offset/=temp_scale;
		for (i=0;i<dash.n_dash;i++)
			dash.dash[i]/=temp_scale;
		art_free(vp);
		vp=vp2;
	}

	svp=art_svp_vpath_stroke(vp,linejoinstyle,linecapstyle,temp_scale*line_width,miter_limit,0.5);
	art_free(vp);

	artcontext_render_svp(svp,clip_x0,clip_y0,clip_x1,clip_y1,
		stroke_color[0],stroke_color[1],stroke_color[2],stroke_color[3],
		CLIP_DATA,wi->bytes_per_line,
		wi->has_alpha?wi->alpha+clip_x0+clip_y0*wi->sx:NULL,wi->sx,
		wi->has_alpha,
		&DI);

	art_svp_free(svp);

	[path removeAllPoints];
}

- (void)DPSimage: (NSAffineTransform*) matrix
		: (int) pixelsWide : (int) pixelsHigh
		: (int) bitsPerSample : (int) samplesPerPixel 
		: (int) bitsPerPixel : (int) bytesPerRow : (BOOL) isPlanar
		: (BOOL) hasAlpha : (NSString *) colorSpaceName
		: (const unsigned char *const [5]) data
{
/* this is very basic, but it's enough to handle cached image representations
and that covers most (all?) actual uses of it */
	int x,y,ox,oy;
	const unsigned char *src=data[0];
	unsigned char *alpha_dest;

	render_run_t ri;

	if (!wi || !wi->data) return;

	if (wi->has_alpha)
	{
		if (DI.inline_alpha)
			alpha_dest=wi->data+DI.inline_alpha_ofs;
		else
			alpha_dest=wi->alpha;
	}
	else
		alpha_dest=NULL;

//	NSLog(@"image (%ix%i) to (%ix%i) %i\n",pixelsWide,pixelsHigh,wi->sx,wi->sy,hasAlpha);

	ox=[matrix transformPoint: NSMakePoint(0,0)].x;
	oy=wi->sy-[matrix transformPoint: NSMakePoint(0,0)].y-pixelsHigh;

	if (bitsPerSample==8 && !isPlanar && bytesPerRow==samplesPerPixel*pixelsWide &&
	    ((samplesPerPixel==3 && bitsPerPixel==24 && !hasAlpha) ||
	     (samplesPerPixel==4 && bitsPerPixel==32 && hasAlpha)))
	{
		for (y=0;y<pixelsHigh;y++)
		{
			for (x=0;x<pixelsWide;x++)
			{
				if (x+ox<clip_x0 || x+ox>=clip_x1 || y+oy<clip_y0 || y+oy>=clip_y1)
				{
					if (hasAlpha)
						src+=4;
					else
						src+=3;
					continue;
				}
				ri.dst=wi->data+(x+ox)*DI.bytes_per_pixel+(y+oy)*wi->bytes_per_line;
				ri.dsta=wi->alpha+(x+ox)+(y+oy)*wi->sx;
				ri.r=src[0];
				ri.g=src[1];
				ri.b=src[2];
				if (hasAlpha)
				{
					ri.a=src[3];
					if (alpha_dest)
					{
						if (src[3]==255)
							RENDER_RUN_OPAQUE_A(&ri,1);
						else if (src[3])
							RENDER_RUN_ALPHA_A(&ri,1);
					}
					else
					{
						if (src[3]==255)
							RENDER_RUN_OPAQUE(&ri,1);
						else if (src[3])
							RENDER_RUN_ALPHA(&ri,1);
					}
					src+=4;
				}
				else
				{
					ri.a=255;
					if (alpha_dest)
						RENDER_RUN_OPAQUE_A(&ri,1);
					else
						RENDER_RUN_OPAQUE(&ri,1);
					src+=3;
				}
			}
		}
	}
	else
	{
		NSLog(@"unimplemented DPSimage");
		NSLog(@"%ix%i  |%@|  bips=%i spp=%i bipp=%i bypr=%i  planar=%i alpha=%i\n",
			pixelsWide,pixelsHigh,matrix,
			bitsPerSample,samplesPerPixel,bitsPerPixel,bytesPerRow,isPlanar,
			hasAlpha);
	}
}

@end


@interface ARTGState (testing)
-(void) GScurrentpath: (NSBezierPath **)p;
@end

@implementation ARTGState (testing)
-(void) GScurrentpath: (NSBezierPath **)p
{
	*p=[path copy];
}
@end


@interface ARTGState (internal_stuff)
#ifdef RDS
-(void) _setup_stuff: (int)window  : (RDSClient *)remote;
#else
-(void) _setup_stuff: (gswindow_device_t *)win : (int)x : (int)y;
#endif
@end

@implementation ARTGState (internal_stuff)


- (void) dealloc
{
	if (dash.dash)
		free(dash.dash);

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

  wi=RETAIN(wi);

  return self;
}

#ifdef RDS
-(void) _setup_stuff: (int)window  : (RDSClient *)remote
{
	NSLog(@"_setup_stuff: %i : %p",window,remote);
	DESTROY(wi);
	wi=[WinImage winImageForWindow: window  remote: remote];
}
#else
-(void) _setup_stuff: (gswindow_device_t *)window : (int)x : (int)y
{
	[self setOffset: NSMakePoint(x, y)];
	DESTROY(wi);
	wi=[WinImage winImageForWindow: window];
}
#endif

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

#ifdef RDS
	artcontext_setup_draw_info(&DI,0x000000ff,0x0000ff00,0x00ff0000,32);
#else
	{
		Display *d=[(XGServer *)server xDisplay];
		Visual *v=DefaultVisual(d,DefaultScreen(d));
		int bpp=DefaultDepth(d,DefaultScreen(d));
		XImage *i=XCreateImage(d,v,bpp,ZPixmap,0,NULL,8,8,8,0);
		bpp=i->bits_per_pixel;
		XDestroyImage(i);

		artcontext_setup_draw_info(&DI,v->red_mask,v->green_mask,v->blue_mask,bpp);
	}

	use_shape_hack=[[NSUserDefaults standardUserDefaults] boolForKey: @"back-art-shape-hack"];
#endif

	return self;
}


- (void) flushGraphics
{ /* TODO: _really_ flush? (ie. force updates and wait for shm completion?) */
#ifndef RDS
	XFlush([(XGServer *)server xDisplay]);
#endif
}

+(void) waitAllContexts
{
}


#ifndef RDS
+(void) _gotShmCompletion: (Drawable)d
{
	int i;
	for (i=0;i<num_wimages;i++)
	{
		if (wimages[i]->drawable==d)
		{
			[wimages[i] _gotShmCompletion];
			return;
		}
	}
	NSLog(@"Warning: gotShmCompletion: couldn't find WinImage for drawable");
}

-(void) gotShmCompletion: (Drawable)d
{
	[[self class] _gotShmCompletion: d];
}
#endif

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
#ifndef RDS
	XBell([(XGServer *)server xDisplay], 50);
#else
#warning TODO beep
#endif
}

/* Private backend methods */
+(void) handleExposeRect: (NSRect)rect forDriver: (void *)driver
{
	[(WinImage *)driver _exposeRect: rect];
}


/* TODO: this is just for testing */
-(void) GScurrentpath: (NSBezierPath **)p
{
	[(ARTGState *)gstate GScurrentpath: p];
}

@end

@implementation ARTContext (ops)
#ifdef RDS
-(void) _rds_set_device: (int)window  remote: (RDSClient *)remote
{
	NSLog(@"_rds_set_device: %i  remote: %@",window,remote);
	[(ARTGState *)gstate _setup_stuff: window : remote];
}
#else
- (void) GSSetDevice: (void*)device : (int)x : (int)y
{
	[(ARTGState *)gstate _setup_stuff: device : x : y];
}
#endif
@end



#ifndef RDS

#include <AppKit/NSImage.h>
@implementation NSImage (dummy)
-(Pixmap) xPixmapMask
{ /* TODO */
	return 0;
}
@end



/*
   XGBitmapImageRep.m

   NSBitmapImageRep for GNUstep GUI X/GPS Backend

   Copyright (C) 1996-1999 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@colorado.edu>
   Author:  Scott Christley <scottc@net-community.com>
   Date: Feb 1996
   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date: May 1998
   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: Mar 1999
   Rewritten: Adam Fedor <fedor@gnu.org>
   Date: May 2000

   This file is part of the GNUstep GUI X/GPS Backend.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#include <config.h>
#include <stdlib.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

#ifdef HAVE_WRASTER_H
#include "wraster.h"
#else
#include "x11/wraster.h"
#endif
#include "x11/XGServerWindow.h"
#include <Foundation/NSData.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSUserDefaults.h>
#include <AppKit/NSBitmapImageRep.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSImage.h>

@interface NSBitmapImageRep (BackEnd)
- (Pixmap) xPixmapMask;
@end


@implementation NSBitmapImageRep (Backend)

#ifdef WITH_WRASTER
+ (NSArray *) _wrasterFileTypes
{
  int i;
  NSMutableArray *warray;
  char **types = RSupportedFileFormats();
  
  i = 0;
  warray = [NSMutableArray arrayWithCapacity: 4];
  while (types[i] != NULL)
    {
      NSString *type = [NSString stringWithCString: types[i]];
      type = [type lowercaseString];
      if (strcmp(types[i], "TIFF") != 0)
	{
	  [warray addObject: type];
	  if (strcmp(types[i], "JPEG") == 0)
	    [warray addObject: @"jpg"];
	  else if (strcmp(types[i], "PPM") == 0)
	    [warray addObject: @"pgm"];
	}
      i++;
    }
  return warray;
}

- _initFromWrasterFile: (NSString *)filename number: (int)imageNumber
{
  int screen;
  RImage *image;
  RContext *context;

  if (imageNumber > 0)
    {
      /* RLoadImage doesn't handle this very well */
      RELEASE(self);
      return nil;
    }

  NSDebugLLog(@"NSImage", @"Loading %@ using wraster routines", filename);
  screen = [[[GSCurrentServer() screenList] objectAtIndex: 0] intValue];
  context = [(XGServer *)GSCurrentServer() xrContextForScreen: screen];
  image = RLoadImage(context, (char *)[filename cString], imageNumber);
  if (!image)
    {
      RELEASE(self);
      return nil;
    }
  [self initWithBitmapDataPlanes: &(image->data)
		pixelsWide: image->width
		pixelsHigh: image->height
		bitsPerSample: 8
	        samplesPerPixel: (image->format == RRGBAFormat) ? 4 : 3
		hasAlpha: (image->format == RRGBAFormat) ? YES : NO
		isPlanar: NO
		colorSpaceName: NSDeviceRGBColorSpace
		bytesPerRow: 0
		bitsPerPixel: 0];

  /* Make NSBitmapImageRep own the data */
  _imageData = [NSMutableData dataWithBytesNoCopy: image->data
				    length: (_bytesPerRow*image->height)];
  RETAIN(_imageData);
  free(image);

  return self;
}
#endif /* WITH_WRASTER */

#endif /* RDS */

