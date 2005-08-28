/*
   Copyright (C) 2002 Free Software Foundation, Inc.

   Author: Banlu Kemiyatorn <object at gmail dot com>

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
#include "cairo/XGCairoSurface.h"
#include <cairo-xlib.h>

#define GSWINDEVICE ((gswindow_device_t *)gsDevice)

@implementation XGCairoSurface

- (id) initWithDevice: (void *)device
{
  Display *dpy;
  Drawable drawable;

  gsDevice = device;

  dpy = GSWINDEVICE->display;
  if (GSWINDEVICE->type != NSBackingStoreNonretained)
    {
      drawable = GSWINDEVICE->buffer;
    }
  else
    {
      drawable = GSWINDEVICE->ident;
    }

  /*
    if (GSWINDEVICE->type != NSBackingStoreNonretained)
    {
    GSWINDEVICE->gdriverProtocol |= GDriverHandlesExpose;
    XSetWindowBackgroundPixmap(GSWINDEVICE->display,
    GSWINDEVICE->ident,
    GSWINDEVICE->buffer);
    }
  */
  
  _surface = cairo_xlib_surface_create(dpy,
				       drawable,
				       DefaultVisual(dpy, DefaultScreen(dpy)),
				       GSWINDEVICE->xframe.size.width,
				       GSWINDEVICE->xframe.size.height);
  return self;
}

- (NSSize) size
{
  return GSWINDEVICE->xframe.size;
}

@end
