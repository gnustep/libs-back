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
#include <AppKit/NSColor.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSGraphics.h>
#include "gsc/GSContext.h"
#include "gsc/GSGState.h"
#include "math.h"

#define CHECK_PATH \
  if (!path) \
    { \
      path = [NSBezierPath new]; \
    }

/* Just temporary until we improve NSColor */
@interface NSColor (PrivateColor)
+ colorWithValues: (float *)values colorSpaceName: colorSpace;
@end

@implementation NSColor (PrivateColor)
+ colorWithValues: (float *)values colorSpaceName: colorSpace
{
  NSColor *color = nil;
  if ([colorSpace isEqual: NSDeviceWhiteColorSpace])
    color = [NSColor colorWithDeviceWhite: values[0] alpha: values[1]];
  else if ([colorSpace isEqual: NSDeviceRGBColorSpace])
    color = [NSColor colorWithDeviceRed: values[0] green: values[1]
		     blue: values[2] alpha: values[3]];
  else if ([colorSpace isEqual: NSDeviceCMYKColorSpace])
    color = [NSColor colorWithDeviceCyan: values[0] magenta: values[1]
		     yellow: values[2] black: values[3] alpha: values[4]];
  else
    DPS_ERROR(DPSundefined, @"Cannot convert colorspace");
  return color;
}
@end



@implementation GSGState

/* Designated initializer. */
- initWithDrawContext: (GSContext *)drawContext
{
  [super init];

  drawcontext = drawContext;
  offset = NSMakePoint(0, 0);
  path   = nil;
  font   = nil;
  fillColorS   = nil;
  strokeColorS = nil;
  [self DPSinitgraphics];
  return self;
}

- (void) dealloc
{
  TEST_RELEASE(font);
  TEST_RELEASE(path);
  RELEASE(ctm);
  RELEASE(textCtm);
  RELEASE(fillColorS);
  RELEASE(strokeColorS);
  [super dealloc];
}

- (id) deepen
{
  NSZone *zone = GSObjCZone(self);

  if (path)
    self->path = [path copyWithZone: zone];

  self->ctm     = [ctm copyWithZone: zone];
  self->textCtm = [ctm copyWithZone: zone];

  // Just retain the other objects
  if (font != nil)
    RETAIN(font);
  if (fillColorS != nil)
    RETAIN(fillColorS);
  if (strokeColorS != nil)
    RETAIN(strokeColorS);

  return self;
}

- copyWithZone: (NSZone *)zone
{
  GSGState *new = (GSGState *)NSCopyObject(self, 0, zone);  
  /* Do a deep copy since gstates are isolated from each other */
  return [new deepen];
}

- (void) setOffset: (NSPoint)theOffset
{
  offset = theOffset;
}

- (NSPoint) offset
{
  return offset;
}

/** Subclasses should override this method to be notified of changes
    in the current color */
- (void) setColor: (device_color_t)color state: (color_state_t)cState
{
  float alpha;
  alpha = fillColor.field[AINDEX];
  if (cState & COLOR_FILL)
    fillColor = color;
  fillColor.field[AINDEX] = alpha;
  alpha = strokeColor.field[AINDEX];
  if (cState & COLOR_STROKE)
    strokeColor = color;
  strokeColor.field[AINDEX] = alpha;
  cstate = cState;
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
  *a = fillColor.field[AINDEX];
}

- (void) DPScurrentcmykcolor: (float*)c : (float*)m : (float*)y : (float*)k
{
  device_color_t new = fillColor;
  new = gsColorToCMYK(new);
  *c = new.field[0];
  *m = new.field[1];
  *y = new.field[2];
  *k = new.field[3];
}

- (void) DPScurrentgray: (float*)gray
{
  device_color_t gcolor;
  gcolor = gsColorToGray(fillColor);
  *gray = gcolor.field[0];
}

- (void) DPScurrenthsbcolor: (float*)h : (float*)s : (float*)b
{
  device_color_t gcolor;
  gcolor = gsColorToHSB(fillColor);
  *h = gcolor.field[0]; *s = gcolor.field[1]; *b = gcolor.field[2];
}

- (void) DPScurrentrgbcolor: (float*)r : (float*)g : (float*)b
{
  device_color_t gcolor;
  gcolor = gsColorToRGB(fillColor);
  *r = gcolor.field[0]; *g = gcolor.field[1]; *b = gcolor.field[2];
}

#define CLAMP(x) \
  if (x < 0.0) x = 0.0; \
  if (x > 1.0) x = 1.0;

- (void) DPSsetalpha: (float)a
{
  CLAMP(a)
  fillColor.field[AINDEX] = strokeColor.field[AINDEX] = a;
  [self setColor: fillColor state: COLOR_FILL];
  [self setColor: strokeColor state: COLOR_STROKE];
}

- (void) DPSsetcmykcolor: (float)c : (float)m : (float)y : (float)k
{
  CLAMP(c)
  CLAMP(m)
  CLAMP(y)
  CLAMP(k)
  [self setColor: gsMakeColor(cmyk_colorspace, c, m, y, k) state: COLOR_BOTH];
}

- (void) DPSsetgray: (float)gray
{
  CLAMP(gray)
  [self setColor: gsMakeColor(gray_colorspace, gray, 0, 0, 0) state: COLOR_BOTH];
}

- (void) DPSsethsbcolor: (float)h : (float)s : (float)b
{
  CLAMP(h)
  CLAMP(s)
  CLAMP(b)
  [self setColor: gsMakeColor(hsb_colorspace, h, s, b, 0) state: COLOR_BOTH];
}

- (void) DPSsetrgbcolor: (float)r : (float)g : (float)b
{
  CLAMP(r)
  CLAMP(g)
  CLAMP(b)
  [self setColor: gsMakeColor(rgb_colorspace, r, g, b, 0) state: COLOR_BOTH];
}


- (void) GSSetFillColorspace: (NSDictionary *)dict
{
  float values[6];
  NSString *colorSpace = [dict objectForKey: GSColorSpaceName];
  if (fillColorS)
    RELEASE(fillColorS);
  memset(values, 0, sizeof(float)*6);
  fillColorS = [NSColor colorWithValues: values colorSpaceName:colorSpace];
  RETAIN(fillColorS);
  [self setColor: gsMakeColor(rgb_colorspace, 0, 0, 0, 0) state: COLOR_FILL];
}

- (void) GSSetStrokeColorspace: (NSDictionary *)dict
{
  float values[6];
  NSString *colorSpace = [dict objectForKey: GSColorSpaceName];
  if (strokeColorS)
    RELEASE(strokeColorS);
  memset(values, 0, sizeof(float)*6);
  strokeColorS = [NSColor colorWithValues: values colorSpaceName:colorSpace];
  RETAIN(strokeColorS);
  [self setColor: gsMakeColor(rgb_colorspace, 0, 0, 0, 0) state: COLOR_STROKE];
}

- (void) GSSetFillColor: (float *)values
{
  device_color_t dcolor;
  NSColor *color;
  NSString *colorSpace;
  if (fillColorS == nil)
    {
      DPS_ERROR(DPSundefined, @"No fill colorspace defined, assume DeviceRGB");
      colorSpace = NSDeviceRGBColorSpace;
    }
  else
    colorSpace = [fillColorS colorSpaceName];
  RELEASE(fillColorS);
  fillColorS = [NSColor colorWithValues: values colorSpaceName:colorSpace];
  RETAIN(fillColorS);
  color = [fillColorS colorUsingColorSpaceName: NSDeviceRGBColorSpace];
  [color getRed: &dcolor.field[0]
	  green: &dcolor.field[1]
	   blue: &dcolor.field[2]
	  alpha: &dcolor.field[AINDEX]];
  [self setColor: dcolor state: COLOR_FILL];  
}

- (void) GSSetStrokeColor: (float *)values
{
  device_color_t dcolor;
  NSColor *color;
  NSString *colorSpace;
  if (strokeColorS == nil)
    {
      DPS_ERROR(DPSundefined, @"No stroke colorspace defined, assume DeviceRGB");
      colorSpace = NSDeviceRGBColorSpace;
    }
  else
    colorSpace = [strokeColorS colorSpaceName];
  RELEASE(strokeColorS);
  strokeColorS = [NSColor colorWithValues: values colorSpaceName:colorSpace];
  RETAIN(strokeColorS);
  color = [strokeColorS colorUsingColorSpaceName: NSDeviceRGBColorSpace];
  [color getRed: &dcolor.field[0]
	  green: &dcolor.field[1]
	   blue: &dcolor.field[2]
	  alpha: &dcolor.field[AINDEX]];
  [self setColor: dcolor state: COLOR_STROKE];  
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

- (void) GSSetCharacterSpacing: (float)extra
{
  charSpacing = extra;
}

- (void) GSSetFont: (NSFont*)newFont
{
  if (font == newFont)
    return;
  ASSIGN(font, newFont);
}

- (void) GSSetFontSize: (float)size
{
  NSFont *newFont;
  if (font == nil)
    return;
  newFont = [NSFont fontWithName: [font fontName] size: size];
  [self GSSetFont: newFont];
}

- (NSAffineTransform *) GSGetTextCTM
{
  return textCtm;
}

- (NSPoint) GSGetTextPosition
{
  return [textCtm pointInMatrixSpace: NSMakePoint(0,0)];
}

- (void) GSSetTextCTM: (NSAffineTransform *)newCtm
{
  ASSIGN(textCtm, newCtm);
}

- (void) GSSetTextDrawingMode: (GSTextDrawingMode)mode
{
  textMode = mode;
}

- (void) GSSetTextPosition: (NSPoint)loc
{
  [textCtm translateToPoint: loc];
}

- (void) GSShowText: (const char *)string : (size_t) length
{
  [self subclassResponsibility: _cmd];
}

- (void) GSShowGlyphs: (const NSGlyph *)glyphs : (size_t) length
{
  [self subclassResponsibility: _cmd];
}


/* ----------------------------------------------------------------------- */
/* Gstate operations */
/* ----------------------------------------------------------------------- */
- (void) DPSinitgraphics
{
  DESTROY(path);
  DESTROY(font);
  DESTROY(fillColorS);
  DESTROY(strokeColorS);
  if (ctm)
    [ctm makeIdentityMatrix];
  else
    ctm = [[NSAffineTransform allocWithZone: GSObjCZone(self)] init];

   /* Initialize colors. By default the same color is used for filling and 
     stroking unless fill and/or stroke color is set explicitly */
  fillColor = gsMakeColor(gray_colorspace, 0, 0, 0, 0);
  [self setColor: fillColor state: COLOR_BOTH];
  fillColor.field[AINDEX] = 1.0;
  strokeColor.field[AINDEX] = 1.0;

  charSpacing = 0;
  textMode    = GSTextFill;
  if (textCtm)
    [textCtm makeIdentityMatrix];
  else
    textCtm = [[NSAffineTransform allocWithZone: GSObjCZone(self)] init];
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

- (void)DPScurveto: (float)x1 : (float)y1 : (float)x2 : (float)y2 : (float)x3 
		  : (float)y3 
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

- (void)DPSrcurveto: (float)x1 : (float)y1 : (float)x2 : (float)y2 : (float)x3 
		   : (float)y3 
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
  NSRect rect = [ctm rectInMatrixSpace: NSMakeRect(x, y, w, h)]; 
  NSBezierPath *oldPath = path;

  path = [NSBezierPath bezierPathWithRect: rect];
  [self DPSclip];
  path = oldPath;
}

- (void) DPSrectfill: (float)x : (float)y : (float)w : (float)h
{
  NSRect rect = [ctm rectInMatrixSpace: NSMakeRect(x, y, w, h)]; 
  NSBezierPath *oldPath = path;

  path = [NSBezierPath bezierPathWithRect: rect];
  [self DPSfill];
  path = oldPath;
}

- (void) DPSrectstroke: (float)x : (float)y : (float)w : (float)h
{
  NSRect rect = [ctm rectInMatrixSpace: NSMakeRect(x, y, w, h)]; 
  NSBezierPath *oldPath = path;

  path = [NSBezierPath bezierPathWithRect: rect];
  [self DPSstroke];
  path = oldPath;
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

- (void) GSRectClipList: (const NSRect *)rects : (int) count
{
  int i;
  NSRect union_rect;

  if (count == 0)
    return;

  /* 
     The specification is not clear if the union of the rects 
     should produce the new clip rect or if the outline of all rects 
     should be used as clip path.
  */
  union_rect = rects[0];
  for (i = 1; i < count; i++)
    union_rect = NSUnionRect(union_rect, rects[i]);

  [self DPSrectclip: NSMinX(union_rect) : NSMinY(union_rect)
	  : NSWidth(union_rect) : NSHeight(union_rect)];
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


