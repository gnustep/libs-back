/* GSGState - Generic graphic state

   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Date: Mar 2002
   
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
#include <Foundation/NSObjCRuntime.h>
#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>
#include <AppKit/NSFont.h>
#include "gsc/GSContext.h"
#include "gsc/GSGState.h"
#include "math.h"

#define CHECK_PATH \
  if (!path) \
    { \
      path = [NSBezierPath new]; \
    }

@implementation GSGState

/* Designated initializer. */
- initWithDrawContext: (GSContext *)drawContext
{
  [super init];

  drawcontext = drawContext;
  ctm = [[NSAffineTransform allocWithZone: GSObjCZone(self)] init];
  path = nil;
  font = nil;
  offset = NSMakePoint(0, 0);
  return self;
}

- (void) dealloc
{
  TEST_RELEASE(font);
  TEST_RELEASE(path);
  RELEASE(ctm);
  [super dealloc];
}

- (id) deepen
{
  NSZone *zone = GSObjCZone(self);

  if (path)
    self->path = [path copyWithZone: zone];

  self->ctm = [ctm copyWithZone: zone];

  // Just retain the font  
  if (font != nil)
    RETAIN(font);

  return self;
}

- copyWithZone: (NSZone *)zone
{
  GSGState *new = (GSGState *)NSCopyObject(self, 0, zone);  
  /* Do a deep copy since gstates are isolated from each other */
  return [new deepen];
}

- (void) setFont: (NSFont*)newFont
{
  if (font == newFont)
    return;
  ASSIGN(font, newFont);
}

- (NSFont*) currentFont
{
  return font;
}

- (void) setOffset: (NSPoint)theOffset
{
  offset = theOffset;
}

- (NSPoint) offset
{
  return offset;
}

- (void) compositeGState: (GSGState *)source
                fromRect: (NSRect)aRect
                 toPoint: (NSPoint)aPoint
                      op: (NSCompositingOperation)op
{
  [self subclassResponsibility: _cmd];
}

- (void) dissolveGState: (GSGState *)source
               fromRect: (NSRect)aRect
                toPoint: (NSPoint)aPoint
                  delta: (float)delta
{
  [self subclassResponsibility: _cmd];
}

- (void) compositerect: (NSRect)aRect
                    op: (NSCompositingOperation)op
{
  [self subclassResponsibility: _cmd];
}

- (NSPoint) pointInMatrixSpace: (NSPoint)aPoint
{
  return [ctm pointInMatrixSpace: aPoint];
}

- (NSPoint) deltaPointInMatrixSpace: (NSPoint)aPoint
{
  return [ctm deltaPointInMatrixSpace: aPoint];
}

- (NSRect) rectInMatrixSpace: (NSRect)rect
{
  return [ctm rectInMatrixSpace: rect];
}

@end

@implementation GSGState (Ops)

/* ----------------------------------------------------------------------- */
/* Color operations */
/* ----------------------------------------------------------------------- */
- (void) DPScurrentalpha: (float*)a
{
  [self notImplemented: _cmd];
}

- (void) DPScurrentcmykcolor: (float*)c : (float*)m : (float*)y : (float*)k
{
  [self notImplemented: _cmd];
}

- (void) DPScurrentgray: (float*)gray
{
  [self notImplemented: _cmd];
}

- (void) DPScurrenthsbcolor: (float*)h : (float*)s : (float*)b
{
  [self notImplemented: _cmd];
}

- (void) DPScurrentrgbcolor: (float*)r : (float*)g : (float*)b
{
  [self notImplemented: _cmd];
}

- (void) DPSsetalpha: (float)a
{
  [self notImplemented: _cmd];
}

- (void) DPSsetcmykcolor: (float)c : (float)m : (float)y : (float)k
{
  [self notImplemented: _cmd];
}

- (void) DPSsetgray: (float)gray
{
  [self notImplemented: _cmd];
}

- (void) DPSsethsbcolor: (float)h : (float)s : (float)b
{
  [self notImplemented: _cmd];
}

- (void) DPSsetrgbcolor: (float)r : (float)g : (float)b
{
  [self notImplemented: _cmd];
}


- (void) GSSetFillColorspace: (NSDictionary *)dict
{
  [self notImplemented: _cmd];
}

- (void) GSSetStrokeColorspace: (NSDictionary *)dict
{
  [self notImplemented: _cmd];
}

- (void) GSSetFillColor: (float *)values
{
  [self notImplemented: _cmd];
}

- (void) GSSetStrokeColor: (float *)values
{
  [self notImplemented: _cmd];
}

/* ----------------------------------------------------------------------- */
/* Text operations */
/* ----------------------------------------------------------------------- */
- (void) DPSashow: (float)x : (float)y : (const char*)s
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSawidthshow: (float)cx : (float)cy : (int)c : (float)ax : (float)ay 
		      : (const char*)s
{
  [self subclassResponsibility: _cmd];
}

- (void) DPScharpath: (const char*)s : (int)b
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSshow: (const char*)s
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSwidthshow: (float)x : (float)y : (int)c : (const char*)s
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSxshow: (const char*)s : (const float*)numarray : (int)size
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSxyshow: (const char*)s : (const float*)numarray : (int)size
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSyshow: (const char*)s : (const float*)numarray : (int)size
{
  [self subclassResponsibility: _cmd];
}


/* ----------------------------------------------------------------------- */
/* Gstate operations */
/* ----------------------------------------------------------------------- */
- (void) DPSinitgraphics
{
  [self subclassResponsibility: _cmd];
}

- (void)DPScurrentflat: (float *)flatness 
{
  if (path)
    *flatness = [path flatness];
  else 
    *flatness = 1.0;
}

- (void) DPScurrentlinecap: (int*)linecap
{
  [self subclassResponsibility: _cmd];
}

- (void) DPScurrentlinejoin: (int*)linejoin
{
  [self subclassResponsibility: _cmd];
}

- (void) DPScurrentlinewidth: (float*)width
{
  [self subclassResponsibility: _cmd];
}

- (void) DPScurrentmiterlimit: (float*)limit
{
  [self subclassResponsibility: _cmd];
}

- (void)DPScurrentpoint: (float *)x : (float *)y 
{
  NSAffineTransform *ictm;
  NSPoint user;

  // This is rather slow, but it is not used very often
  ictm = [ctm copyWithZone: GSObjCZone(self)];
  [ictm inverse];
  user = [ictm pointInMatrixSpace: [path currentPoint]];
  RELEASE(ictm);
  *x = user.x;
  *y = user.y;
}

- (void) DPScurrentstrokeadjust: (int*)b
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSsetdash: (const float*)pat : (int)size : (float)offset
{
  [self subclassResponsibility: _cmd];
}

- (void)DPSsetflat: (float)flatness 
{
  if (path)
    [path setFlatness: flatness];
}

- (void) DPSsetlinecap: (int)linecap
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSsetlinejoin: (int)linejoin
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSsetlinewidth: (float)width
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSsetmiterlimit: (float)limit
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSsetstrokeadjust: (int)b
{
  [self subclassResponsibility: _cmd];
}

/* ----------------------------------------------------------------------- */
/* Matrix operations */
/* ----------------------------------------------------------------------- */
- (void)DPSconcat: (const float *)m
{
  [ctm concatenateWithMatrix: m];
}

- (void)DPSinitmatrix 
{
  [ctm makeIdentityMatrix];
}

- (void)DPSrotate: (float)angle 
{
  [ctm rotateByDegrees: angle];
}

- (void)DPSscale: (float)x : (float)y 
{
  [ctm scaleBy: x : y];
}

- (void)DPStranslate: (float)x : (float)y 
{
  [ctm translateToPoint: NSMakePoint(x, y)];
}

- (NSAffineTransform *) GSCurrentCTM
{
  return [ctm copy];
}

- (void) GSSetCTM: (NSAffineTransform *)newctm
{
  ASSIGN(ctm, newctm);
}

- (void) GSConcatCTM: (NSAffineTransform *)newctm
{
  [ctm concatenateWith: newctm];
}

/* ----------------------------------------------------------------------- */
/* Paint operations */
/* ----------------------------------------------------------------------- */
- (void) DPSarc: (float)x : (float)y : (float)r : (float)angle1 : (float)angle2 
{
  NSPoint center = [ctm pointInMatrixSpace: NSMakePoint(x, y)];
  NSSize  radius = [ctm sizeInMatrixSpace: NSMakeSize(r, r)];

  CHECK_PATH;
  [path appendBezierPathWithArcWithCenter: center  
	radius: radius.width
	startAngle: angle1
	endAngle: angle2
	clockwise: NO];
}

- (void) DPSarcn: (float)x : (float)y : (float)r : (float)angle1 : (float)angle2 
{
  NSPoint center = [ctm pointInMatrixSpace: NSMakePoint(x, y)];
  NSSize  radius = [ctm sizeInMatrixSpace: NSMakeSize(r, r)];

  CHECK_PATH;
  [path appendBezierPathWithArcWithCenter: center  
	radius: radius.width
	startAngle: angle1
	endAngle: angle2
	clockwise: YES];
}

- (void)DPSarct: (float)x1 : (float)y1 : (float)x2 : (float)y2 : (float)r 
{
  [self notImplemented: _cmd];
}

- (void) DPSclip
{
  [self subclassResponsibility: _cmd];
}

- (void)DPSclosepath 
{
  CHECK_PATH;
  [path closePath];
}

- (void)DPScurveto: (float)x1 : (float)y1 : (float)x2 : (float)y2 : (float)x3 : (float)y3 
{
  NSPoint p1 = [ctm pointInMatrixSpace: NSMakePoint(x1, y1)];
  NSPoint p2 = [ctm pointInMatrixSpace: NSMakePoint(x2, y2)];
  NSPoint p3 = [ctm pointInMatrixSpace: NSMakePoint(x3, y3)];

  CHECK_PATH;
  [path curveToPoint: p3 controlPoint1: p1 controlPoint2: p2];
}

- (void) DPSeoclip
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSeofill
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSfill
{
  [self subclassResponsibility: _cmd];
}

- (void)DPSflattenpath 
{
  if (path)
    ASSIGN(path, [path bezierPathByFlatteningPath]);
}

- (void) DPSinitclip;
{
  [self subclassResponsibility: _cmd];
}

- (void)DPSlineto: (float)x : (float)y 
{
  NSPoint p = [ctm pointInMatrixSpace: NSMakePoint(x, y)];

  CHECK_PATH;
  [path lineToPoint: p];
}

- (void)DPSmoveto: (float)x : (float)y 
{
  NSPoint p = [ctm pointInMatrixSpace: NSMakePoint(x, y)];

  CHECK_PATH;
  [path moveToPoint: p];
}

- (void)DPSnewpath 
{
  if (path)
    [path removeAllPoints];
}

- (void)DPSpathbbox: (float *)llx : (float *)lly : (float *)urx : (float *)ury 
{
  if (path)
    {
      NSRect rect = [path controlPointBounds];
      
      // FIXME Should convert back to user space
      if (llx)
	*llx = NSMinX(rect);
      if (lly)
	*lly = NSMinY(rect);
      if (urx)
	*urx = NSMaxX(rect);
      if (ury)
	*ury = NSMaxY(rect);
    }
}

- (void)DPSrcurveto: (float)x1 : (float)y1 : (float)x2 : (float)y2 : (float)x3 : (float)y3 
{
  NSPoint p1 = [ctm deltaPointInMatrixSpace: NSMakePoint(x1, y1)];
  NSPoint p2 = [ctm deltaPointInMatrixSpace: NSMakePoint(x2, y2)];
  NSPoint p3 = [ctm deltaPointInMatrixSpace: NSMakePoint(x3, y3)];
 
  CHECK_PATH;
  [path relativeCurveToPoint: p3
	controlPoint1: p1
	controlPoint2: p2];
}

- (void) DPSrectclip: (float)x : (float)y : (float)w : (float)h
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSrectfill: (float)x : (float)y : (float)w : (float)h
{
  [self subclassResponsibility: _cmd];
}

- (void) DPSrectstroke: (float)x : (float)y : (float)w : (float)h
{
  [self subclassResponsibility: _cmd];
}

- (void)DPSreversepath 
{
  if (path)
    ASSIGN(path, [path bezierPathByReversingPath]);
}

- (void)DPSrlineto: (float)x : (float)y 
{
  NSPoint p = [ctm deltaPointInMatrixSpace: NSMakePoint(x, y)];
 
  CHECK_PATH;
  [path relativeLineToPoint: p];
}

- (void)DPSrmoveto: (float)x : (float)y 
{
  NSPoint p = [ctm deltaPointInMatrixSpace: NSMakePoint(x, y)];
 
  CHECK_PATH;
  [path relativeMoveToPoint: p];
}

- (void) DPSstroke;
{
  [self subclassResponsibility: _cmd];
}

- (void) GSSendBezierPath: (NSBezierPath *)newpath
{
  CHECK_PATH;
  [path appendBezierPath: path];
}

- (void) GSRectFillList: (const NSRect *)rects : (int) count
{
  int i;
  for (i=0; i < count; i++)
    [self DPSrectfill: NSMinX(rects[i]) : NSMinY(rects[i])
	  : NSWidth(rects[i]) : NSHeight(rects[i])];
}

- (void)DPSimage: (NSAffineTransform*) matrix 
		: (int) pixelsWide : (int) pixelsHigh
		: (int) bitsPerSample : (int) samplesPerPixel 
		: (int) bitsPerPixel : (int) bytesPerRow : (BOOL) isPlanar
		: (BOOL) hasAlpha : (NSString *) colorSpaceName
		: (const unsigned char *const [5]) data
{
  [self subclassResponsibility: _cmd];
}
@end


