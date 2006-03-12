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

static Class __defaultSurfaceClass;

@implementation CairoSurface 

+ (void) setDefaultSurfaceClass: (Class)aClass
{
  __defaultSurfaceClass = aClass;
}

+ (id) allocWithZone: (NSZone*)zone
{
  return NSAllocateObject(__defaultSurfaceClass, 0, zone);
}

- (id) initWithDevice: (void *) device
{
  /* TODO FIXME make a more abstract struct for the device */
  [self subclassResponsibility:_cmd];

  return self;
}

- (void) dealloc
{
  //NSLog(@"CairoSurface dealloc");
  if (_surface != NULL)
    {
      cairo_surface_destroy(_surface);
    }
  [super dealloc];
}

- (NSString *) description
{
  return [NSString stringWithFormat:@"<%@ %p xr:%p>", [self class], self, _surface];
}

-(NSSize) size
{
  [self subclassResponsibility:_cmd];
  return NSMakeSize(0, 0);
}

- (cairo_surface_t *) surface
{
  return _surface;
}

@end
