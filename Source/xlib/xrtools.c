/* xrtools - Color conversion routines and other low-level X support

   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Date: Oct 1998
   
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
#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "xlib/xrtools.h"

xr_device_color_t 
xrMakeColor(xr_device_colorspace_t space, float a, float b, float c, float d)
{
  xr_device_color_t color;
  color.space = space;
  color.field[0] = a;
  color.field[1] = b;
  color.field[2] = c;
  color.field[3] = d;
  return color;
}

xr_device_color_t
xrGrayToRGB(xr_device_color_t  color)
{
  return xrMakeColor(rgb_colorspace, color.field[0], color.field[0], 
	      color.field[0], 0);
}

xr_device_color_t 
xrHSBToRGB(xr_device_color_t  color)
{
  int i;
  float h, s, v;
  float f, p, q, t;
  float red, green, blue;

  h = color.field[0];
  s = color.field[1];
  v = color.field[2];

  if (s == 0) 
    return xrMakeColor(rgb_colorspace, v, v, v, 0);

  h = h * 6;
  i = (int)h;
  f = h - i;
  p = v * (1.0 - s);
  q = v * (1.0 - s * f);
  t = v * (1.0 - s * (1 - f));
  
  switch (i) 
    {
    case 0:
      red = v;
      green = t;
      blue = p;
      break;
    case 1:
      red = q;
      green = v;
      blue = p;
      break;
    case 2:
      red = p;
      green = v;
      blue = t;
      break;
    case 3:
      red = p;
      green = q;
      blue = v;
      break;
    case 4:
      red = t;
      green = p;
      blue = v;
      break;
    case 5:
      red = v;
      green = p;
      blue = q;
      break;
    }
  return xrMakeColor(rgb_colorspace, red, green, blue, 0);
}

/* FIXME */   
xr_device_color_t 
xrCMYKToRGB(xr_device_color_t  color)
{
  float c, m, y, k;
  float red, green, blue;
  double white;

  c = color.field[0];
  m = color.field[1];
  y = color.field[2];
  k = color.field[3];
  white = 1 - k;
	      
  if (k == 0)
    {
      red = 1 - c;
      green = 1 - m;
      blue = 1 - y;
    }
  else if (k == 1)
    {
      red = 0;
      green = 0;
      blue = 0;
    }
  else
    {  
      red = (c > white ? 0 : white - c);
      green = (m > white ? 0 : white - m);
      blue = (y > white ? 0 : white - y);
    }
  return xrMakeColor(rgb_colorspace, red, green, blue, 0);
}

xr_device_color_t 
xrColorToRGB(xr_device_color_t color)
{
  xr_device_color_t new;

  switch(color.space)
    {
    case gray_colorspace:
      new = xrGrayToRGB(color);
      break;
    case rgb_colorspace:
      new = color;
      break;
    case hsb_colorspace: 
      new = xrHSBToRGB(color);
      break;
    case cmyk_colorspace: 
      new = xrCMYKToRGB(color);
      break;
    default:
      break;
    }
  return new;
}

xr_device_color_t 
xrColorToGray(xr_device_color_t color)
{
  xr_device_color_t new;

  new.space = gray_colorspace;
  switch(color.space)
    {
    case gray_colorspace:
      new = color;
      break;
    case hsb_colorspace:
    case cmyk_colorspace: 
      color = xrColorToRGB(color);
      /* NO BREAK */
    case rgb_colorspace:
      new.field[0] = 
	((0.3*color.field[0]) + (0.59*color.field[1]) + (0.11*color.field[2]));
      break;
    default:
      break;
    }
  return new;
}

/* FIXME: Not implemented */
xr_device_color_t 
xrColorToCMYK(xr_device_color_t color)
{
  xr_device_color_t new;

  new.space = cmyk_colorspace;
  switch(color.space)
    {
    case gray_colorspace:
      break;
    case rgb_colorspace:
      break;
    case hsb_colorspace:
      break;
    case cmyk_colorspace: 
      new = color;
      break;
    default:
      break;
    }
  return new;
}

/* FIXME: Not implemented */
xr_device_color_t 
xrColorToHSB(xr_device_color_t color)
{
  xr_device_color_t new;

  new.space = hsb_colorspace;
  switch(color.space)
    {
    case gray_colorspace:
      break;
    case rgb_colorspace:
      break;
    case hsb_colorspace:
      new = color;
      break;
    case cmyk_colorspace: 
      break;
    default:
      break;
    }
  return new;
}
