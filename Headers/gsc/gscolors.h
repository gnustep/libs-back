/* gscolors - Color conversion routines

   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
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

#ifndef _gscolors_h_INCLUDE
#define _gscolors_h_INCLUDE

#define AINDEX 5

typedef enum {
  gray_colorspace, rgb_colorspace, hsb_colorspace, cmyk_colorspace
} device_colorspace_t;

typedef struct _device_color {
  device_colorspace_t space;
  float field[6];
} device_color_t;

/* Internal conversion of colors to pixels values */
extern device_color_t gsMakeColor(device_colorspace_t space, 
				  float a, float b, float c, float d);
extern device_color_t gsColorToRGB(device_color_t color);
extern device_color_t gsColorToGray(device_color_t color);
extern device_color_t gsColorToCMYK(device_color_t color);
extern device_color_t gsColorToHSB(device_color_t color);

#endif


