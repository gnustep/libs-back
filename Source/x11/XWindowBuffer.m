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

#include <Foundation/NSUserDefaults.h>

#include "x11/XGServer.h"
#include "x11/XGServerWindow.h"

#include "x11/XWindowBuffer.h"

#include <math.h>
#include <sys/ipc.h>
#include <sys/shm.h>


#include <X11/extensions/shape.h>


static XWindowBuffer **window_buffers;
static int num_window_buffers;


static int use_shape_hack = 0; /* this is an ugly hack :) */

static int use_xshm = 1;



@implementation XWindowBuffer

+ windowBufferForWindow: (gswindow_device_t *)awindow
              depthInfo: (struct XWindowBuffer_depth_info_s *)aDI
{
  int i;
  XWindowBuffer *wi;

  for (i = 0; i < num_window_buffers; i++)
    {
      if (window_buffers[i]->window == awindow)
	break;
    }
  if (i == num_window_buffers)
    {
      wi = [[XWindowBuffer alloc] init];
      wi->window = awindow;
      window_buffers = realloc(window_buffers,
        sizeof(XWindowBuffer *) * (num_window_buffers + 1));
      if (!window_buffers)
	{
	  NSLog(@"Out of memory (failed to allocate %i bytes)",
		sizeof(XWindowBuffer *) * (num_window_buffers + 1));
	  exit(1);
	}
      window_buffers[num_window_buffers++] = wi;
    }
  else
    {
      wi = window_buffers[i];
      wi = RETAIN(wi);
    }

  wi->DI = *aDI;
  wi->gc = awindow->gc;
  wi->drawable = awindow->ident;
  wi->display = awindow->display;

  wi->window->gdriverProtocol = GDriverHandlesExpose | GDriverHandlesBacking;
  wi->window->gdriver = wi;

  /* TODO: resolve properly.
     -x11 is creating buffers before I have a chance to tell it not to, so
     I'm freeing them here to reduce memory consumption (and prevent
     leaks, though that should be fixed now) */
  if (awindow->buffer)
    {
      XFreePixmap (awindow->display, awindow->buffer);
      awindow->buffer = 0;
    }
  if (awindow->alpha_buffer)
    {
      XFreePixmap (awindow->display, awindow->alpha_buffer);
      awindow->alpha_buffer = 0;
    }

  /* create the image if necessary */
  if (!wi->ximage ||
      wi->sx != awindow->xframe.size.width ||
      wi->sy != awindow->xframe.size.height)
    {
      wi->sx = wi->window->xframe.size.width;
/*		printf("%@ updating image for %p (%gx%g)\n", wi, wi->window,
			wi->window->xframe.size.width, wi->window->xframe.size.height);*/
      if (wi->ximage)
	{
	  if (wi->use_shm)
	    {
	      XShmDetach(wi->display, &wi->shminfo);
	      XDestroyImage(wi->ximage);
	      shmdt(wi->shminfo.shmaddr);
	    }
	  else
	    XDestroyImage(wi->ximage);
	}
      if (wi->pixmap)
	{
	  XFreePixmap(wi->display,wi->pixmap);
	  XSetWindowBackground(wi->display,wi->window->ident,None);
	  wi->pixmap=0;
	}

      wi->has_alpha = 0;
      if (wi->alpha)
	{
	  free(wi->alpha);
	  wi->alpha = NULL;
	}

      wi->pending_put = wi->pending_event = 0;

      wi->ximage = NULL;

      /* TODO: only use shared memory for 'real' on-screen windows. how can
      we tell? don't create shared buffer until first expose? */
      /* The primary problems seems to be the system limit on the _number_
      of shared memory segments, not their total size, so we only create
      shared buffers for reasonably large buffers and assume that the small
      ones are just caches of images and will never be displayed, anyway
      (and if they are displayed, it won't cost much, since they're small).
      */
      if (wi->window->xframe.size.width * wi->window->xframe.size.height < 4096)
        goto no_xshm;

#define WARN @" Falling back to normal XImage:s (will be slower)."
      if (!use_xshm)
        goto no_xshm;

      /* Use XShm if possible, else fall back to normal XImage:s */
      if (!XShmQueryExtension(wi->display))
	{
static BOOL xshm_warned = NO;
	  if (!xshm_warned)
	    NSLog(@"XShm not supported." WARN);
	  xshm_warned = YES;
	  goto no_xshm;
	}

      wi->use_shm = 1;
      wi->ximage = XShmCreateImage(wi->display,
	DefaultVisual(wi->display, DefaultScreen(wi->display)),
	aDI->drawing_depth, ZPixmap, NULL, &wi->shminfo,
	wi->window->xframe.size.width,
	wi->window->xframe.size.height);
      if (!wi->ximage)
	{
	  NSLog(@"Warning: XShmCreateImage failed!" WARN);
	  goto no_xshm;
	}
      wi->shminfo.shmid = shmget(IPC_PRIVATE,
	wi->ximage->bytes_per_line * wi->ximage->height,
	IPC_CREAT | 0700);

      if (wi->shminfo.shmid == -1)
	{
	  NSLog(@"Warning: shmget() failed: %m." WARN);
	  XDestroyImage(wi->ximage);
	  goto no_xshm;
	}

      wi->shminfo.shmaddr = wi->ximage->data = shmat(wi->shminfo.shmid, 0, 0);
      if ((int)wi->shminfo.shmaddr == -1)
	{
	  NSLog(@"Warning: shmat() failed: %m." WARN);
	  XDestroyImage(wi->ximage);
	  shmctl(wi->shminfo.shmid, IPC_RMID, 0);
	  goto no_xshm;
	}

      wi->shminfo.readOnly = 0;
      if (!XShmAttach(wi->display, &wi->shminfo))
	{
	  NSLog(@"Warning: XShmAttach() failed." WARN);
	  XDestroyImage(wi->ximage);
	  shmdt(wi->shminfo.shmaddr);
	  shmctl(wi->shminfo.shmid, IPC_RMID, 0);
	  goto no_xshm;
	}

      /* We try to create a shared pixmap using the same buffer, and set
	 it as the background of the window. This allows X to handle expose
	 events all by itself, which avoids white flashing when things are
	 dragged across a window. */
      /* TODO: we still get and handle expose events, although we don't
	 need to. */
      wi->pixmap=XShmCreatePixmap(wi->display,wi->drawable,
				  wi->ximage->data,&wi->shminfo,
				  wi->window->xframe.size.width,
				  wi->window->xframe.size.height,
				  aDI->drawing_depth);
      if (wi->pixmap) /* TODO: this doesn't work */
	{
	  XSetWindowBackgroundPixmap(wi->display,wi->window->ident,wi->pixmap);
	}

      /* On some systems (eg. freebsd), X can't attach to the shared segment
      if it's marked for destruction, so we make sure it's attached before
      marking it. */
      XSync(wi->display,False);

      /* Mark the segment as destroyed now. Since we're attached, it won't
      actually be destroyed, but if we crashed before doing this, it wouldn't
      be destroyed despite nobody being attached anymore. */
      shmctl(wi->shminfo.shmid, IPC_RMID, 0);

      if (!wi->ximage)
	{
no_xshm:
	  wi->use_shm = 0;
	  wi->ximage = XCreateImage(wi->display, DefaultVisual(wi->display,
	    DefaultScreen(wi->display)), aDI->drawing_depth, ZPixmap, 0, NULL,
	    wi->window->xframe.size.width, wi->window->xframe.size.height,
	    8, 0);

	  wi->ximage->data = malloc(wi->ximage->height * wi->ximage->bytes_per_line);
	  if (!wi->ximage->data)
	    {
	      XDestroyImage(wi->ximage);
	      wi->ximage = NULL;
	    }
/*TODO?	wi->ximage = XGetImage(wi->display, wi->drawable,
		0, 0, wi->window->xframe.size.width, wi->window->xframe.size.height,
		-1, ZPixmap);*/
	}
    }

  if (wi->ximage)
    {
      wi->sx = wi->ximage->width;
      wi->sy = wi->ximage->height;
      wi->data = wi->ximage->data;
      wi->bytes_per_line = wi->ximage->bytes_per_line;
      wi->bits_per_pixel = wi->ximage->bits_per_pixel;
      wi->bytes_per_pixel = wi->bits_per_pixel / 8;
//		NSLog(@"%@ ximage=%p data=%p\n", wi->ximage, wi->data);
    }
  else
    {
      NSLog(@"Warning: failed to create image for window!");
      wi->data = NULL;
    }

  return wi;
}


extern int XShmGetEventBase(Display *d);

-(void) _gotShmCompletion
{
  if (!use_shm)
    return;

  pending_event = 0;
  if (pending_put)
    {
      NSRect r = pending_rect;
      pending_put = 0;
      if (r.origin.x + r.size.width>window->xframe.size.width)
	{
	  r.size.width = window->xframe.size.width - r.origin.x;
	  if (r.size.width <= 0)
	    return;
	}
      if (r.origin.y + r.size.height>window->xframe.size.height)
	{
	  r.size.height = window->xframe.size.height - r.origin.y;
	  if (r.size.height <= 0)
	    return;
	}
      if (!XShmPutImage(display, drawable, gc, ximage,
			r.origin.x, r.origin.y,
			r.origin.x, r.origin.y,
			r.size.width, r.size.height,
			1))
	{
	  NSLog(@"XShmPutImage failed?");
	}
      else
	{
	  pending_event = 1;
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
  NSRect r2;

  r = NSIntersectionRect(r, NSMakeRect(0, 0,
    window->xframe.size.width, window->xframe.size.height));
  if (NSIsEmptyRect(r))
    return;

  r2.origin.x=floor(r.origin.x);
  r2.origin.y=floor(r.origin.y);
  r2.size.width=ceil(r.size.width+r.origin.x-r2.origin.x);
  r2.size.height=ceil(r.size.height+r.origin.y-r2.origin.y);

  r=r2;

  if (use_shm)
    {

      /* HACK: lets try to use shaped windows to get some use out of
	 destination alpha */
      if (has_alpha && use_shape_hack)
	{
static int warn = 0;
	  Pixmap p;
	  int dsize = ((sx + 7) / 8) * sy;
	  unsigned char *buf = malloc(dsize);
	  unsigned char *dst;
	  int bofs;
	  unsigned char *a;
	  int as;
	  int i, x;

	  if (!warn)
	    NSLog(@"Warning: activating shaped windows");
	  warn = 1;

	  memset(buf, 0xff, dsize);

#define CUTOFF 128

	  if (DI.inline_alpha)
	    {
	      a = data + DI.inline_alpha_ofs;
	      as = DI.bytes_per_pixel;
	    }
	  else
	    {
	      a = alpha;
	      as = 1;
	    }

	  for (bofs = 0, i = sx * sy, x = sx, dst = buf; i; i--, a += as)
	    {
	      if (*a < CUTOFF)
		{
		  *dst = *dst & ~(1 << bofs);
		}
	      bofs++;
	      if (bofs == 8)
		{
		  dst++;
		  bofs = 0;
		}
	      x--;
	      if (!x)
		{
		  if (bofs)
		    {
		      bofs = 0;
		      dst++;
		    }
		  x = sx;
		}
	    }
#undef CUTOFF
//NSLog(@"check shape");
	  if (old_shape_size == dsize && !memcmp(old_shape, buf, dsize))
	    {
	      free(buf);
//		NSLog(@"  same shape");
	    }
	  else
	    {
//		NSLog(@"  updating");
	      p = XCreatePixmapFromBitmapData(display, window->ident, buf, sx, sy, 1, 0, 1);
	      free(old_shape);
	      old_shape = buf;
	      old_shape_size = dsize;
	      XShapeCombineMask(display, window->ident,
				ShapeBounding, 0, 0, p, ShapeSet);
	      XFreePixmap(display, p);
	    }
	}

      if (pending_event)
	{
	  if (!pending_put)
	    {
	      pending_put = 1;
	      pending_rect = r;
	    }
	  else
	    {
	      pending_rect = NSUnionRect(pending_rect, r);
	    }
	}
      else
	{
	  pending_put = 0;
	  if (!XShmPutImage(display, drawable, gc, ximage,
			    r.origin.x, r.origin.y,
			    r.origin.x, r.origin.y,
			    r.size.width, r.size.height,
			    1))
	    {
	      NSLog(@"XShmPutImage failed?");
	    }
	  else
	    {
	      pending_event = 1;
	    }
	}

      /* Performance hack. Check right away for ShmCompletion
	 events. */
      {
	XEvent e;
	while (XCheckTypedEvent(window->display,
	    XShmGetEventBase(window->display) + ShmCompletion,
	    &e))
	  {
	    [isa _gotShmCompletion: ((XShmCompletionEvent *)&e)->drawable];
	  }
      }
    }
  else if (ximage)
    XPutImage(display, drawable, gc, ximage,
	      r.origin.x, r.origin.y,
	      r.origin.x, r.origin.y,
	      r.size.width, r.size.height);
}

-(void) needsAlpha
{
  if (has_alpha)
    return;

  if (!data)
    return;

//	NSLog(@"needs alpha for %p: %ix%i", self, sx, sy);

  if (DI.inline_alpha)
    {
      int i;
      unsigned char *s;
      alpha = NULL;
      has_alpha = 1;
      /* fill the alpha channel */
      for (i = 0, s = data + DI.inline_alpha_ofs; i < sx * sy;
	   i++, s += DI.bytes_per_pixel)
	*s = 0xff;
      return;
    }

  alpha = malloc(sx * sy);
  if (!alpha)
    {
      NSLog(@"Warning! Failed to allocate alpha buffer for window!");
      return;
    }

//	NSLog(@"got buffer at %p", alpha);

  has_alpha = 1;
  memset(alpha, 0xff, sx * sy);
}

-(void) dealloc
{
  int i;

  for (i = 0; i < num_window_buffers; i++)
    if (window_buffers[i] == self) break;
  if (i < num_window_buffers)
    {
      num_window_buffers--;
      for (; i < num_window_buffers; i++)
	window_buffers[i] = window_buffers[i + 1];
    }

  if (ximage)
    {
      if (pixmap)
	{
	  XFreePixmap(display,pixmap);
	  pixmap=0;
	}

      if (use_shm)
	{
	  XShmDetach(display, &shminfo);
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


+(void) initialize
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  use_shape_hack = [ud boolForKey: @"XWindowBuffer-shape-hack"];

  if ([ud objectForKey: @"XWindowBufferUseXShm"])
    use_xshm = [ud boolForKey: @"XWindowBufferUseXShm"];
}


+(void) _gotShmCompletion: (Drawable)d
{
  int i;
  for (i = 0; i < num_window_buffers; i++)
    {
      if (window_buffers[i]->drawable == d)
	{
	  [window_buffers[i] _gotShmCompletion];
	  return;
	}
    }
  NSLog(@"Warning: gotShmCompletion: couldn't find XWindowBuffer for drawable");
}

@end

