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

#ifndef XWindowBuffer_h
#define XWindowBuffer_h

#include <X11/extensions/XShm.h>


struct XWindowBuffer_depth_info_s
{
  int drawing_depth;
  int bytes_per_pixel;
  BOOL inline_alpha;
  int inline_alpha_ofs;
};

/*
XWindowBuffer maintains an XImage for a window. Each ARTGState that
renders to that window uses the same XWindowBuffer (and thus the same
buffer, etc.).

Many states might render to the same window, so we need to make sure
that there's only one XWindowBuffer for each window. */
@interface XWindowBuffer : NSObject
{
@public
  gswindow_device_t *window;

@private
  GC gc;
  Drawable drawable;
  XImage *ximage;
  Display *display;

  int use_shm;
  XShmSegmentInfo shminfo;


  struct XWindowBuffer_depth_info_s DI;


  /* While a XShmPutImage is in progress we don't try to call it
  again. The pending updates are stored here, and when we get the
  ShmCompletion event, we handle them. */
  int pending_put;     /* There are pending updates */
  NSRect pending_rect; /* in this rectangle. */

  int pending_event;   /* We're waiting for the ShmCompletion event. */


  /* This is for the ugly shape-hack */
  unsigned char *old_shape;
  int old_shape_size;

@public
  unsigned char *data;
  int sx, sy;
  int bytes_per_line, bits_per_pixel, bytes_per_pixel;

  /* If has_alpha is 1 and alpha is NULL, the alpha is stored in data
  somehow. The drawing mechanism code should know how to deal with
  it. */
  unsigned char *alpha;
  int has_alpha;
}

/* this returns a _retained_ object */
+ windowBufferForWindow: (gswindow_device_t *)awindow
              depthInfo: (struct XWindowBuffer_depth_info_s *)aDI;

/*
Note that alpha is _not_ guaranteed to exist after this has been called;
you still need to check has_alpha. If the call fails, a message will be
logged.

(In ARTGState, I handle failures by simply ignoring the operation that
required alpha.)
*/
-(void) needsAlpha;

-(void) _gotShmCompletion;
-(void) _exposeRect: (NSRect)r;
+(void) _gotShmCompletion: (Drawable)d;

@end


#endif

