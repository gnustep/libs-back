/*
   Copyright (C) 2002 Free Software Foundation, Inc.

   Author: Banlu Kemiyatorn <object at gmail dot com>

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

#include "x11/XGServer.h"
#include "x11/XGServerWindow.h"
#include "cairo/XGCairoSurface.h"
#include <cairo-xlib.h>

#define GSWINDEVICE ((gswindow_device_t *)gsDevice)

@implementation XGCairoSurface

- (id) initWithDevice: (void *)device
{
  Display *dpy;
  Drawable drawable;
  Visual* visual;
  XWindowAttributes attributes;

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

  if (!XGetWindowAttributes (dpy, GSWINDEVICE->ident, &attributes))
    {
      visual = DefaultVisual (dpy, DefaultScreen (dpy));
    }
  else
    {
      visual = attributes.visual;
    }

  _surface = cairo_xlib_surface_create(dpy,
			       drawable,
			       visual,
			       GSWINDEVICE->xframe.size.width,
			       GSWINDEVICE->xframe.size.height);
  
  return self;
}

- (NSSize) size
{
  return GSWINDEVICE->xframe.size;
}

@end
