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
#include <X11/Xatom.h>
#include <X11/Intrinsic.h>
#include "xlib/xrtools.h"

/* Internal conversion of colors to pixels values */
u_long   
xrGrayToPixel(RContext* context, float gray)
{
  XColor cc;
  RColor rcolor;
  rcolor.red = 255. * gray;
  rcolor.green = 255. * gray;
  rcolor.blue = 255. * gray;
  rcolor.alpha = 0;
  RGetClosestXColor(context, &rcolor, &cc);
  return cc.pixel;
}

u_long   
xrRGBToPixel(RContext* context, float red, float green, float blue)
{
  XColor cc;
  RColor rcolor;
  rcolor.red = 255. * red;
  rcolor.green = 255. * green;
  rcolor.blue = 255. * blue;
  rcolor.alpha = 0;
  RGetClosestXColor(context, &rcolor, &cc);
  return cc.pixel;
}

u_long   
xrHSBToPixel(RContext* context, float h, float s, float v)
{
  int i;
  float f, p, q, t;
  float red, green, blue;

  if (s == 0) 
    return xrRGBToPixel(context, v, v, v);

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
    return xrRGBToPixel(context, red, green, blue);
}

/* Not implemented. FIXME */
u_long   
xrCMYKToPixel(RContext* context, float c, float m, float y, float k) 
{
  float red, green, blue;
  double white = 1 - k;
	      
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
  return xrRGBToPixel(context, red, green, blue);
}

u_long   
xrColorToPixel(RContext* context, xr_device_color_t  color)
{
  u_long pix;
  switch(color.space)
    {
    case gray_colorspace:
      pix = xrGrayToPixel(context, color.field[0]);
      break;
    case rgb_colorspace:
      pix = xrRGBToPixel(context, color.field[0], 
			 color.field[1], color.field[2]);
      break;
    case hsb_colorspace:
      pix = xrHSBToPixel(context, color.field[0], 
			 color.field[1], color.field[2]);
      break;
    case cmyk_colorspace: 
      pix = xrCMYKToPixel(context, color.field[0], color.field[1],
			  color.field[2], color.field[3]);
      break;
    default:
      break;
    }
    return pix;
}

xr_device_color_t 
xrConvertToGray(xr_device_color_t color)
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
      color = xrConvertToRGB(color);
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

xr_device_color_t 
xrConvertToRGB(xr_device_color_t color)
{
  xr_device_color_t new;

  new.space = rgb_colorspace;
  switch(color.space)
    {
    case gray_colorspace:
      new.field[0] = color.field[0];
      new.field[1] = color.field[0];
      new.field[2] = color.field[0];
      break;
    case rgb_colorspace:
      new = color;
      break;
    case hsb_colorspace: 
    case cmyk_colorspace: 
      break;
    default:
      break;
    }
  return new;
}

xr_device_color_t 
xrConvertToHSB(xr_device_color_t color)
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

xr_device_color_t 
xrConvertToCMYK(xr_device_color_t color)
{
  xr_device_color_t new;

  new.space = gray_colorspace;
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
