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

#include <Foundation/NSUserDefaults.h>
#include <math.h>
#include "cairo/XGCairoSurface.h"

#define GSWINDEVICE ((gswindow_device_t *)gsDevice)

@implementation XGCairoSurface

+ (CairoSurface *) createSurfaceForDevice: (void *)device
				depthInfo: (CairoInfo *)cairoInfo
{
#define NEWGSWINDEVICE ((gswindow_device_t *)device)
  XGCairoSurface *surface;
    
  surface = [[self alloc] initWithDevice: NEWGSWINDEVICE];
  
  NSAssert(NEWGSWINDEVICE->buffer, @"FIXME! CairoSurface: Strange, a window doesn't have buffer");

  return surface;
#undef NEWGSWINDEVICE
}


- (NSString *) description
{
  return [NSString stringWithFormat: @"<XGCairoSurface %p xr:%p>", self, xrSurface];
}

- (id) initWithDevice: (void *)device
{
  /* FIXME format is ignore when Visual isn't NULL
   * Cairo may change this API
   */
  gsDevice = device;
  /*
    if (GSWINDEVICE->type != NSBackingStoreNonretained)
    {
    GSWINDEVICE->gdriverProtocol |= GDriverHandlesExpose;
    XSetWindowBackgroundPixmap(GSWINDEVICE->display,
    GSWINDEVICE->ident,
    GSWINDEVICE->buffer);
    }
  */
  
  xrSurface = cairo_xlib_surface_create(GSWINDEVICE->display,
					GSWINDEVICE->buffer,
					DefaultVisual(GSWINDEVICE->display,
						      DefaultScreen(GSWINDEVICE->display)),
					0,
					DefaultColormap(GSWINDEVICE->display,
							DefaultScreen(GSWINDEVICE->display)));

  return self;
}

- (void) setAsTargetOfCairo: (cairo_t *)ct
{
  /*
    if (GSWINDEVICE->type != NSBackingStoreNonretained)
    {
    GSWINDEVICE->gdriverProtocol |= GDriverHandlesExpose;
    XSetWindowBackgroundPixmap(GSWINDEVICE->display,
    GSWINDEVICE->ident,
    GSWINDEVICE->buffer);
    }
  */
  //cairo_set_target_drawable(ct, GSWINDEVICE->display, GSWINDEVICE->buffer);
  cairo_set_target_surface(ct, xrSurface);
}

- (void) dealloc
{
  cairo_surface_destroy(xrSurface);
  [super dealloc];
}

- (void) logDevice
{
  NSLog(@"device %p id:%p buff:%p",self,GSWINDEVICE->ident,GSWINDEVICE->buffer);
}

- (NSSize) size
{
  return GSWINDEVICE->xframe.size;
}

@end

