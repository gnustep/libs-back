/*
   Copyright (C) 2007 Free Software Foundation, Inc.

   Author: Fred Kiefer <fredkiefer@gmx.de>

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

#include "cairo/CairoPSSurface.h"
#include <cairo-ps.h>

@implementation CairoPSSurface

- (id) initWithDevice: (void *)device
{
  NSDictionary *info;
  NSString *path;

  info = (NSDictionary*)device;
  path = [info objectForKey: @"NSOutputFile"];
  //NSLog(@"Write to file %@", path);
  // This gets only set later on:
  // @"NSPrintSheetBounds"
  

  // FIXME: Hard coded size in points
  size = NSMakeSize(400, 400);
  _surface = cairo_ps_surface_create([path fileSystemRepresentation], size.width, size.height);
  if (cairo_surface_status(_surface))
    {
      NSLog(@"Could not create surface");
      DESTROY(self);
    }

  return self;
}

- (NSSize) size
{
  return size;
}

- (void) setSize: (NSSize)newSize
{
  size = newSize;
  cairo_ps_surface_set_size(_surface, size.width, size.height);
}


- (void) writeComment: (NSString *)comment
{
  cairo_ps_surface_dsc_comment(_surface, [comment UTF8String]);
}

@end
