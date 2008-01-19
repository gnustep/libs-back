/*
   Copyright (C) 2002, 2003, 2004, 2005 Free Software Foundation, Inc.

   Author:  Alexander Malmberg <alexander@malmberg.org>

   This file is part of GNUstep.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/


#include <Foundation/NSDebug.h>
#include <Foundation/NSDictionary.h>

#include "ARTGState.h"
#include "blit.h"
#include "ftfont.h"

#ifndef RDS
#include "x11/XWindowBuffer.h"
#endif

// Could use NSSwapInt() instead
static unsigned int flip_bytes(unsigned int i)
{
  return ((i >> 24) & 0xff)
	|((i >>  8) & 0xff00)
	|((i <<  8) & 0xff0000)
	|((i << 24) & 0xff000000);
}

static int byte_order(void)
{
  union
  {
    unsigned int i;
    char c;
  } foo;
  foo.i = 1;
  return foo.c != 1;
}

@implementation ARTContext

+ (void)initializeBackend
{
  NSDebugLLog(@"back-art",@"Initializing libart/freetype backend");

  [NSGraphicsContext setDefaultContextClass: [ARTContext class]];
  [FTFontInfo initializeBackend];
}

+ (Class) GStateClass
{
  return [ARTGState class];
}

- (void) setupDrawInfo
{
#ifdef RDS
  {
    RDSServer *s = (RDSServer *)server;
    int bpp;
    int red_mask, green_mask, blue_mask;

    [s getPixelFormat: &bpp masks: &red_mask : &green_mask : &blue_mask];
    artcontext_setup_draw_info(&DI, red_mask, green_mask, blue_mask, bpp);
  }
#else
  {
    Display *d = [(XGServer *)server xDisplay];
    int bpp;
    Visual *visual;
    XVisualInfo template;
    XVisualInfo *visualInfo;
    int numMatches;
    XImage *i;

    /*
    We need a visual that we can generate pixel values for by ourselves.
    Thus, we try to find a DirectColor or TrueColor visual. If that fails,
    we use the default visual and hope that it's usable.
    */
    template.class = DirectColor;
    visualInfo = XGetVisualInfo(d, VisualClassMask, &template, &numMatches);
    if (!visualInfo)
      {
        template.class = TrueColor;
        visualInfo = XGetVisualInfo(d, VisualClassMask, &template, &numMatches);
      }
    if (visualInfo)
      {
        visual = visualInfo->visual;
        bpp = visualInfo->depth;
        XFree(visualInfo);
      }
    else
      {
        visual = DefaultVisual(d, DefaultScreen(d));
        bpp = DefaultDepth(d, DefaultScreen(d));
      }
    
    i = XCreateImage(d, visual, bpp, ZPixmap, 0, NULL, 8, 8, 8, 0);
    bpp = i->bits_per_pixel;
    XDestroyImage(i);

    /* If the server doesn't have the same endianness as we do, we need
       to flip the masks around (well, at least sometimes; not sure
       what'll really happen for 15/16bpp modes).  */
    {
      int us = byte_order(); /* True iff we're big-endian.  */
      int them = ImageByteOrder(d); /* True iff the server is big-endian.  */
      if (us != them)
        {
          visual->red_mask = flip_bytes(visual->red_mask);
          visual->green_mask = flip_bytes(visual->green_mask);
          visual->blue_mask = flip_bytes(visual->blue_mask);
        }
    }

    /* Only returns if the visual was usable.  */
    artcontext_setup_draw_info(&DI, visual->red_mask, visual->green_mask,
			       visual->blue_mask, bpp);
  }
#endif
}

- (void) flushGraphics
{ 
  /* TODO: _really_ flush? (ie. force updates and wait for shm completion?) */
#ifndef RDS
  XFlush([(XGServer *)server xDisplay]);
#endif
}

#ifndef RDS
+ (void) _gotShmCompletion: (Drawable)d
{
  [XWindowBuffer _gotShmCompletion: d];
}

- (void) gotShmCompletion: (Drawable)d
{
  [XWindowBuffer _gotShmCompletion: d];
}
#endif

/* Private backend methods */
+ (void) handleExposeRect: (NSRect)rect forDriver: (void *)driver
{
  [(XWindowBuffer *)driver _exposeRect: rect];
}

@end

@implementation ARTContext (ops)
- (void) GSSetDevice: (void*)device : (int)x : (int)y
{
  [self setupDrawInfo];
  [(ARTGState *)gstate GSSetDevice: device : x : y];
}

- (void) GSCurrentDevice: (void **)device : (int *)x : (int *)y
{
  [(ARTGState *)gstate GSCurrentDevice: device : x : y];
}
@end
