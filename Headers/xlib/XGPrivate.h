/* 
   XGPrivate.h

   Copyright (C) 2002 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@gnu.org>
   Date: Mar 2002
   
   This file is part of the GNUstep GUI X/GPS Backend.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/ 

#ifndef _XGPrivate_h_INCLUDE
#define _XGPrivate_h_INCLUDE

#ifdef HAVE_WRASTER_H
#include "wraster.h"
#else
#include "x11/wraster.h"
#endif

#include "xlib/XGContext.h"
#include "xlib/xrtools.h"
#include <AppKit/GSFontInfo.h>

/* Font function (defined in XGFontManager) */
extern NSString	*XGXFontName(NSString *fontName, float size);

/* Font functions (defined in XGCommonFont) */
extern NSString *XGFontName(Display *dpy, XFontStruct *font_struct);
extern NSString	*XGFontFamily(Display *dpy, XFontStruct *font_struct);
extern float XGFontPointSize(Display *dpy, XFontStruct *font_struct);
extern int XGWeightOfFont(Display *dpy, XFontStruct *info);
extern NSFontTraitMask XGTraitsOfFont(Display *dpy, XFontStruct *info);
extern BOOL XGFontIsFixedPitch(Display *dpy, XFontStruct *font_struct);
extern NSString *XGFontPropString(Display *dpy, XFontStruct *font_struct, 
				  Atom atom);
extern unsigned long XGFontPropULong(Display *dpy, XFontStruct *font_struct, 
			      Atom atom);

@interface XGFontEnumerator : GSFontEnumerator
{
}
@end

@interface XGFontInfo : GSFontInfo
{
  XFontStruct *font_info;
}
@end

@interface GSFontInfo (XBackend)

- (void) drawString:  (NSString*)string
	  onDisplay: (Display*) xdpy drawable: (Drawable) draw
	       with: (GC) xgcntxt at: (XPoint) xp;
- (void) draw: (const char*) s lenght: (int) len 
    onDisplay: (Display*) xdpy drawable: (Drawable) draw
	 with: (GC) xgcntxt at: (XPoint) xp;
- (float) widthOf: (const char*) s lenght: (int) len;
- (void) setActiveFor: (Display*) xdpy gc: (GC) xgcntxt;

@end

/* In XGBitmap.m */
extern int _pixmap_combine_alpha(RContext *context,
                      RXImage *source_im, RXImage *source_alpha,
                      RXImage *dest_im, RXImage *dest_alpha,
                      XRectangle srect,
                      NSCompositingOperation op,
                      XGDrawMechanism drawMechanism,
				 float fraction);

extern int _bitmap_combine_alpha(RContext *context,
		unsigned char * data_planes[5],
		int width, int height,
		int bits_per_sample, int samples_per_pixel,
		int bits_per_pixel, int bytes_per_row,
		int colour_space, BOOL one_is_black,
		BOOL is_planar, BOOL has_alpha, BOOL fast_min,
		RXImage *dest_im, RXImage *dest_alpha,
		XRectangle srect, XRectangle drect,
		NSCompositingOperation op,
		XGDrawMechanism drawMechanism);


#endif




