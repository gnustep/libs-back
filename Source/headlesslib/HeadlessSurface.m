/*
   Copyright (C) 2004, 2023 Free Software Foundation, Inc.

   Re-writen by Gregory Casamento <greg.casamento@gmail.com>
   Based on work by Marcian Lytwyn <gnustep@advcsi.com>
   Based on work by Author: Banlu Kemiyatorn <object at gmail dot com>

   This file is part of GNUstep.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

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

#include "headlesslib/HeadlessSurface.h"

@implementation HeadlessSurface

- (id) initWithDevice: (void *) device
{
  /* TODO FIXME make a more abstract struct for the device */
  [self subclassResponsibility:_cmd];

  return self;
}

- (void) dealloc
{
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

- (void) setSize: (NSSize)newSize
{
  [self subclassResponsibility:_cmd];
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmismatched-return-types"

- (cairo_surface_t *) surface
{
  return _surface;
}

#pragma GCC diagnostic pop

- (void) handleExposeRect: (NSRect)rect
{
}

- (BOOL) isDrawingToScreen
{
  return YES;
}

@end
