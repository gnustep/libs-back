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

#include "x11/XGServer.h"
#include "x11/XGServerWindow.h"
#include "x11/XWindowBuffer.h"
#include "cairo/XGCairoXImageSurface.h"

#define GSWINDEVICE ((gswindow_device_t *)gsDevice)

@implementation XGCairoXImageSurface

- (id) initWithDevice: (void *)device
{
  struct XWindowBuffer_depth_info_s di;

  gsDevice = device;

  di.drawing_depth = 24;
  di.bytes_per_pixel = 4;
  di.inline_alpha = YES;
  di.inline_alpha_ofs = 0;
  // This method is somewhat special as it does not return an autoreleased object
  wi = [XWindowBuffer windowBufferForWindow: GSWINDEVICE depthInfo: &di];

  _surface = cairo_image_surface_create_for_data((unsigned char*)wi->data, 
                                                 CAIRO_FORMAT_ARGB32, 
                                                 wi->sx, wi->sy, 
                                                 wi->bytes_per_line);
  
  return self;
}

- (void) dealloc
{
  DESTROY(wi);
  [super dealloc];
}

- (NSSize) size
{
  return GSWINDEVICE->xframe.size;
}

@end

