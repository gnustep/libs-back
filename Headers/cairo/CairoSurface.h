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

#ifndef CairoSurface_h
#define CairoSurface_h

#include <cairo.h>
#include <Foundation/Foundation.h>

typedef struct _CairoInfo
{
} CairoInfo;

@interface CairoSurface : NSObject
{
@public
  void *gsDevice;
  cairo_surface_t *_surface;
}

+ (CairoSurface *) surfaceForDevice: (void *) device
                        depthInfo: (CairoInfo *) cairoInfo;

+ (CairoSurface *) createSurfaceForDevice:(void *)device
								depthInfo:(CairoInfo *)cairoInfo;

- (id) initWithDevice:(void *)device;

- (NSSize) size;

- (cairo_surface_t *) surface;

@end

#endif

