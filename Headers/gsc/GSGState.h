/* GSGState - Implements generic graphic state drawing for non-PS backends

   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by: Adam Fedor <fedor@boulder.colorado.edu>
   Date: Nov 1995
   Extracted from XGPS: Fred Kiefer <FredKiefer@gmx.de>
   Date: March 2002
   
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

#ifndef _GSGState_h_INCLUDE
#define _GSGState_h_INCLUDE

#include <AppKit/NSGraphicsContext.h>   // needed for NSCompositingOperation
#include <Foundation/NSArray.h>
#include <Foundation/NSObject.h>

@class NSAffineTransform;
@class NSBezierPath;
@class NSFont;
@class GSContext;

typedef enum {
  path_stroke, path_fill, path_eofill, path_clip, path_eoclip
} ctxt_object_t;

@interface GSGState : NSObject
{
@public
  GSContext *drawcontext;
  NSAffineTransform *ctm;
  NSPoint offset;               /* Offset from Drawable origin */
  NSBezierPath *path;	        /* current path */
  NSFont *font;

  BOOL viewIsFlipped;
}

- initWithDrawContext: (GSContext *)context;
- deepen;

- (void) setOffset: (NSPoint)theOffset;
- (NSPoint) offset;

- (void) setFont: (NSFont*)font;
- (NSFont*) currentFont;

- (void) compositeGState: (GSGState *)source
                fromRect: (NSRect)aRect
                 toPoint: (NSPoint)aPoint
                      op: (NSCompositingOperation)op;

- (void) dissolveGState: (GSGState *)source
               fromRect: (NSRect)aRect
                toPoint: (NSPoint)aPoint
                  delta: (float)delta;

- (void) compositerect: (NSRect)aRect
                    op: (NSCompositingOperation)op;

- (NSPoint) pointInMatrixSpace: (NSPoint)point;
- (NSPoint) deltaPointInMatrixSpace: (NSPoint)point;
- (NSRect) rectInMatrixSpace: (NSRect)rect;

@end

#include "GSGStateOps.h"

#endif /* _GSGState_h_INCLUDE */

