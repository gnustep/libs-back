/*
   GSXftFontInfo

   NSFont helper for GNUstep GUI X/GPS Backend

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Fred Kiefer <fredkiefer@gmx.de>
   Date: July 2001

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

// Include this before we include any objC defines, otherwise id is defined
#include <X11/Xlib.h>
#define id xwindowsid
#include <X11/Xft/Xft.h>
#undef id

#include <GNUstepGUI/GSFontInfo.h>

@interface FcFontEnumerator : GSFontEnumerator
{
}
@end

@interface GSXftFontInfo : GSFontInfo
{
  XftFont *font_info;
}

- (void) drawString:  (NSString*)string
	  onDisplay: (Display*) xdpy drawable: (Drawable) draw
	       with: (GC) xgcntxt at: (XPoint) xp;
- (void) draw: (const char*) s lenght: (int) len 
    onDisplay: (Display*) xdpy drawable: (Drawable) draw
	 with: (GC) xgcntxt at: (XPoint) xp;
- (float) widthOf: (const char*) s lenght: (int) len;
- (void) setActiveFor: (Display*) xdpy gc: (GC) xgcntxt;

@end
