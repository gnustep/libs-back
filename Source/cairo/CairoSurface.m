/*
   Copyright (C) 2004 Free Software Foundation, Inc.

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

#include "cairo/CairoSurface.h"

#include <math.h>
#include "config.h"

#ifdef USE_GLITZ
@class XGCairoGlitzSurface;
#else
@class XGCairoSurface;
#endif

static CairoSurface **surface_list;
static int num_cairo_surfaces;
static Class __defaultSurfaceClass;

@implementation CairoSurface 

+ (void) setDefaultSurfaceClass: (Class)aClass
{
  __defaultSurfaceClass = aClass;
}

+ (void) initializeBackend
{
  if (BUILD_SERVER == SERVER_x11)
    {
#ifdef USE_GLITZ
    [self setDefaultSurfaceClass: [XGCairoGlitzSurface class]];
#else
    [self setDefaultSurfaceClass: [XGCairoSurface class]];
#endif
    }
}

+ (void) _listSurface
{
  int i;
  id str = @"surfaces :";

  if (surface_list == NULL)
    {
      NSLog(@"no surface");
      return;
    }

  for (i = 0; i < num_cairo_surfaces; i++)
    {
      str = [NSString stringWithFormat: @"%@ %p", str, surface_list[i]];
    }
  NSLog(str);
}

+ (CairoSurface *) surfaceForDevice: (void *)device 
			  depthInfo: (CairoInfo *)cairoInfo
{
  id newsurface;
  int i;

  for (i = 0; i < num_cairo_surfaces; i++)
    {
      if (surface_list[i]->gsDevice == device)
	{
	  return surface_list[i];
	}
    }

  /* a surface for the device isn't found
   * create a new one */

  newsurface =[self createSurfaceForDevice: device depthInfo:cairoInfo];
  num_cairo_surfaces++;
  surface_list = realloc (surface_list, sizeof (void *) * num_cairo_surfaces);

  if (!surface_list)
    {
      NSLog(@"Woah.. buy some memory man! CairoSurface.m meet OOMKiller! %d",
	     __LINE__);
      exit(1);
    }

  surface_list[num_cairo_surfaces - 1] = newsurface;

  return newsurface;
}

+ (CairoSurface *) createSurfaceForDevice: (void *)device 
				depthInfo: (CairoInfo *)cairoInfo
{
  if (__defaultSurfaceClass == self)
    {
      [self subclassResponsibility: _cmd];
      return nil;
    }

  return [__defaultSurfaceClass createSurfaceForDevice: device depthInfo: cairoInfo];
}

- (id) initWithDevice: (void *) device
{
  /* TODO FIXME make a more abstract struct for the device */
  /* _surface = cairo_surface_create_for_image(); */
  [self subclassResponsibility:_cmd];

  return self;
}

- (void) dealloc
{
  //NSLog(@"CairoSurface dealloc");
  [super dealloc];
}

- (void) setAsTargetOfCairo: (cairo_t *)ct
{
  [self subclassResponsibility:_cmd];
}

- (NSString *) description
{
  return [NSString stringWithFormat:@"<CairoSurface %p xr:%p>", self, NULL];
}

-(NSSize) size
{
  [self subclassResponsibility:_cmd];
  return NSMakeSize(0, 0);
}

@end
