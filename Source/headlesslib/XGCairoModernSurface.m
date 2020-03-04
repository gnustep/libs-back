/*
   Copyright (C) 2011 Free Software Foundation, Inc.

   Author: Eric Wasylishen <ewasylishen@gmail.com>

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

#include "config.h"
#include "xheadless/XGServer.h"
#include "xheadless/XGServerWindow.h"
#include "headlesslib/XGCairoModernSurface.h"

#define GSWINDEVICE ((gswindow_device_t *)gsDevice)

@implementation XGCairoModernSurface

- (id) initWithDevice: (void *)device
{
  return self;
}

- (void) dealloc
{
  [super dealloc];
}

- (NSSize) size
{
  return GSWINDEVICE->xframe.size;
}

- (void) handleExposeRect: (NSRect)rect
{
}

@end

