/* XGGState - Implements graphic state drawing for Xlib

   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by: Adam Fedor <fedor@boulder.colorado.edu>
   Date: Nov 1995
   
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

#ifndef _XGGState_h_INCLUDE
#define _XGGState_h_INCLUDE

#include <Foundation/NSArray.h>
#include <Foundation/NSObject.h>
#include "gsc/GSGState.h"
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include "x11/XGServer.h"

@class NSBezierPath;
@class NSFont;

@interface XGGState : GSGState
{
@public
  void      *context;
  void      *windevice;
  XGDrawMechanism drawMechanism;
  GC	    xgcntxt;
  GC	    agcntxt;
  XGCValues gcv;
  Drawable  draw;
  Drawable  alpha_buffer;
  Region clipregion;

  BOOL drawingAlpha;
  BOOL sharedGC;  /* Do we own the GC or share it? */
}

- (void) setWindowDevice: (void *)device;
- (void) setGraphicContext: (GC)xGraphicContext;
- (void) setGCValues: (XGCValues)values withMask: (int)mask;
- (void) setClipMask;
- (Region) xClipRegion;

- (BOOL) hasDrawable;
- (BOOL) hasGraphicContext;
- (void *) windevice;
- (Drawable) drawable;
- (GC) graphicContext;
- (NSRect) clipRect;

- (XPoint) viewPointToX: (NSPoint)aPoint;
- (XRectangle) viewRectToX: (NSRect)aRect;
- (XPoint) windowPointToX: (NSPoint)aPoint;
- (XRectangle) windowRectToX: (NSRect)aRect;

@end

#endif /* _XGGState_h_INCLUDE */

