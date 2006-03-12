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

#define GSWINDEVICE ((gswindow_device_t *)gsDevice)

@implementation XGCairoGlitzSurface

- (id) initWithDevice: (void *)device
{
  glitz_format_t *format;
  Colormap cm;
  XVisualInfo *vi;
  unsigned long format_options = GLITZ_FORMAT_OPTION_ONSCREEN_MASK;

  /* FIXME format is ignore when Visual isn't NULL
   * Cairo may change this API
   */
  gsDevice = device;

  /*
    if (GSWINDEVICE->type != NSBackingStoreNonretained)
    {
    XSetWindowBackgroundPixmap(GSWINDEVICE->display,
    GSWINDEVICE->ident,
    GSWINDEVICE->buffer);
    }
  */

  format_options |= GLITZ_FORMAT_OPTION_NO_MULTISAMPLE_MASK;
  format_options |= GLITZ_FORMAT_OPTION_SINGLEBUFFER_MASK;
  
  format = glitz_glx_find_standard_format(GSWINDEVICE->display,
					  GSWINDEVICE->screen,
					  format_options,
					  GLITZ_STANDARD_RGB24);
  
  if (!format)
    {
      NSLog(@"XGCairoGlitzSurface : %d : no format",__LINE__);
      exit(1);
    }

  vi = glitz_glx_get_visual_info_from_format(GSWINDEVICE->display,
					     GSWINDEVICE->screen,
					     format);
  
  if (!vi)
    {
      NSLog(@"XGCairoGlitzSurface : %d : no visual info",__LINE__);
      exit(1);
    }
  
  /*
    cm = XCreateColormap(GSWINDEVICE->display,
    GSWINDEVICE->root, vi->visual, AllocNone);
    
    XSetWindowColormap(GSWINDEVICE->display,GSWINDEVICE->ident,cm);
  */

  _surface = cairo_glitz_surface_create(glitz_glx_surface_create(GSWINDEVICE->display,
								 GSWINDEVICE->screen,
								 format,
								 GSWINDEVICE->ident));
  
  return self;
}

- (NSSize) size
{
  return GSWINDEVICE->xframe.size;
}

@end

