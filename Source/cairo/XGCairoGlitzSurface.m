/*
   Copyright (C) 2002 Free Software Foundation, Inc.

   Author:  Alexander Malmberg <alexander@malmberg.org>
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

#include "cairo/XGCairoGlitzSurface.h"
#include <cairo-glitz.h>
#include <glitz-glx.h>

#define GSWINDEVICE ((gswindow_device_t *)gsDevice)

@implementation XGCairoGlitzSurface

- (id) initWithDevice: (void *)device
{
  glitz_drawable_format_t templ;
  glitz_drawable_format_t *dformat = NULL;
  glitz_drawable_t *drawable = NULL;
  glitz_format_t *format = NULL;
  glitz_surface_t *surface = NULL;

  gsDevice = device;

  /*
    if (GSWINDEVICE->type != NSBackingStoreNonretained)
    {
    XSetWindowBackgroundPixmap(GSWINDEVICE->display,
    GSWINDEVICE->ident,
    GSWINDEVICE->buffer);
    }
  */

  templ.doublebuffer = 0;
  dformat = glitz_glx_find_drawable_format_for_visual(GSWINDEVICE->display,
						      GSWINDEVICE->screen,
						      //				       GLITZ_FORMAT_DOUBLEBUFFER_MASK,
						      //				       &templ,
						      DefaultVisual(GSWINDEVICE->display, GSWINDEVICE->screen)); //FIXME: this does not work
  
  if (!dformat)
    {
      NSLog(@"XGCairoGlitzSurface : %d : no format",__LINE__);
      exit(1);
    }

  drawable = glitz_glx_create_drawable_for_window(GSWINDEVICE->display,
						  GSWINDEVICE->screen,
						  dformat,
						  GSWINDEVICE->ident,
						  GSWINDEVICE->xframe.size.width,
						  GSWINDEVICE->xframe.size.height);
  if (!drawable)
    {
      NSLog(@"XGCairoGlitzSurface : %d : no glitz drawable", __LINE__);
      exit(1);
    }

  format = glitz_find_standard_format(drawable, GLITZ_STANDARD_ARGB32);
  if (!format)
    {
      NSLog(@"XGCairoGlitzSurface : %d : couldn't find ARGB32 surface format", __LINE__);
      exit(1);
    }

  surface = glitz_surface_create(drawable, format,
				 GSWINDEVICE->xframe.size.width,
				 GSWINDEVICE->xframe.size.height,
				 0, NULL);
  if (!surface)
    {
      NSLog(@"XGCairoGlitzSurface : %d : couldn't create glitz surface", __LINE__);
      exit(1);
    }

  glitz_surface_attach(surface, drawable, GLITZ_DRAWABLE_BUFFER_FRONT_COLOR);
  _surface = cairo_glitz_surface_create(surface);
  
  return self;
}

- (NSSize) size
{
  return GSWINDEVICE->xframe.size;
}

@end

