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

#ifndef ARTWindowBuffer_h
#define ARTWindowBuffer_h

#include <X11/extensions/XShm.h>

/*
ARTWindowBuffer maintains an XImage for a window. Each ARTGState that
renders to that window uses the same WinImage (and thus the same buffer,
etc.).

Many states might render to the same window, so we need to make sure
that there's only one WinImage for each window. */
@interface ARTWindowBuffer : NSObject
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
  int sx, sy;
  int bytes_per_line, bits_per_pixel, bytes_per_pixel;

  /* If has_alpha is 1 and alpha is NULL, the alpha is stored in data
  somehow. The drawing mechanism code should know how to deal with
  it. */
  unsigned char *alpha;
  int has_alpha;


  unsigned char *old_shape;
  int old_shape_size;
}

#ifdef RDS
+ artWindowBufferForWindow: (int)awindow  remote: (RDSClient *)remote;
#else
+ artWindowBufferForWindow: (gswindow_device_t *)awindow;
#endif

-(void) needsAlpha;

-(void) _gotShmCompletion;
-(void) _exposeRect: (NSRect)r;

+(void) initializeBackendWithDrawInfo: (struct draw_info_s *)d;

#ifndef RDS
+(void) _gotShmCompletion: (Drawable)d;
#endif

@end


#endif

