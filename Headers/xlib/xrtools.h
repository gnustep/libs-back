/* xrtools - Color conversion routines and other low-level X support

   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Nov 1994
   
   This file is part of the GNU Objective C User Interface Library.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#ifndef _xrtools_h_INCLUDE
#define _xrtools_h_INCLUDE

#ifdef HAVE_WRASTER_H
#include "wraster.h"
#else
#include "x11/wraster.h"
#endif

typedef enum {
  gray_colorspace, rgb_colorspace, hsb_colorspace, cmyk_colorspace
} xr_device_colorspace_t;

typedef struct _xr_device_color {
  xr_device_colorspace_t space;
  float field[6];
} xr_device_color_t;

/* Internal conversion of colors to pixels values */
extern u_long	xrGrayToPixel(RContext * context, float gray);
extern u_long	xrRGBToPixel(RContext * context, float red, 
			float green, float blue);
extern u_long	xrHSBToPixel(RContext * context, float h, float s, float b);
extern u_long	xrCMYKToPixel(RContext * context, float c, float m, 
			float y, float k); 
extern u_long	xrColorToPixel(RContext * context, xr_device_color_t color);

extern xr_device_color_t xrConvertToGray(xr_device_color_t color);
extern xr_device_color_t xrConvertToRGB(xr_device_color_t color);
extern xr_device_color_t xrConvertToHSB(xr_device_color_t color);
extern xr_device_color_t xrConvertToCMYK(xr_device_color_t color);

#endif


