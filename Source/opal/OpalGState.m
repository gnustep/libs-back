/*
   OpalGState.m

   Copyright (C) 2013 Free Software Foundation, Inc.

   Author: Ivan Vucica <ivan@vucica.net>
   Date: June 2013

   This file is part of GNUstep.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/

#import <CoreGraphics/CoreGraphics.h>
#import <X11/Xlib.h>
#import "opal/OpalGState.h"
#import "opal/OpalSurface.h"
#import "x11/XGServerWindow.h"

#define CGCTX [self cgContext]

@implementation OpalGState

// MARK: Minimum required methods
// MARK: -

- (void) DPSinitclip
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  OPContextResetClip(CGCTX);
}

- (void) DPSclip
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  CGContextClip(CGCTX);
}

- (void) DPSfill
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  //CGContextFillPath(CGCTX);
}

- (void) DPSimage: (NSAffineTransform *)matrix
                 : (NSInteger)pixelsWide
		 : (NSInteger)pixelsHigh
                 : (NSInteger)bitsPerSample 
		 : (NSInteger)samplesPerPixel
                 : (NSInteger)bitsPerPixel
		 : (NSInteger)bytesPerRow
                 : (BOOL)isPlanar
		 : (BOOL)hasAlpha
                 : (NSString *)colorSpaceName
		 : (const unsigned char *const[5])data
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  CGContextSaveGState(CGCTX);
  CGContextSetRGBFillColor(CGCTX, 1, 0, 0, 1);
  CGContextConcatCTM(CGCTX, *(CGAffineTransform*)matrix);
  CGContextFillRect(CGCTX, CGRectMake(0, 0, pixelsWide, pixelsHigh));
  CGContextRestoreGState(CGCTX);
}

- (void) compositeGState: (OpalGState *)source
                fromRect: (NSRect)srcRect 
                 toPoint: (NSPoint)destPoint 
                      op: (NSCompositingOperation)op
                fraction: (CGFloat)delta
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
#if 1
  CGContextSaveGState(CGCTX);
  CGContextSetRGBFillColor(CGCTX, 1, 1, 0, 1);
  CGContextFillRect(CGCTX, CGRectMake(destPoint.x, destPoint.y, srcRect.size.width, srcRect.size.height));
  CGContextRestoreGState(CGCTX);
#else
  CGRect srcCGRect = CGRectMake(srcRect.origin.x, srcRect.origin.y, 
                    srcRect.size.width, srcRect.size.height);

  // FIXME: this presumes that the backing cgContext of 'source' is
  // an OpalSurface with a backing CGBitmapContext
  CGImageRef backingImage = CGBitmapContextCreateImage([source cgContext]);
  CGContextMoveToPoint(CGCTX, destPoint.x, destPoint.y);
  // TODO: this ignores op
  // TODO: this ignores delta
  CGContextDrawImage(CGCTX, srcCGRect, backingImage);
  CGImageRelease(backingImage);
#endif
}

- (void) compositerect: (NSRect)aRect
                    op: (NSCompositingOperation)op
{
  NSLog(@"%p (%@): %s - %@", self, [self class], __PRETTY_FUNCTION__, NSStringFromRect(aRect));
  
  CGContextSaveGState(CGCTX);
  [self DPSinitmatrix];
  CGContextFillRect(CGCTX, CGRectMake(aRect.origin.x,  [_opalSurface device]->buffer_height -  aRect.origin.y, 
    aRect.size.width, aRect.size.height));
  CGContextRestoreGState(CGCTX); 
}

- (void) DPSsetdash: (const CGFloat*)pat
                   : (NSInteger)size
                   : (CGFloat)offset
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  // TODO: stub
}
- (void) DPSstroke
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  CGContextStrokePath(CGCTX);
}

@end

// MARK: Initialization methods
// MARK: -

@implementation OpalGState (InitializationMethods)

/* SOME NOTES:
   - GState approximates a cairo context: a drawing state.
   - Surface approximates a cairo surface: a place to draw things.

   - CGContext seems to be a mix of these two: surface + state.

   Should we unite these two somehow? Can we unite these two somehow?
   Possibly not. We still need to support bitmap contexts, pdf contexts
   etc which contain both state and contents.

   So, we will still need surfaces (containing CGContexts, hence including
   state) and GState as a wrapper around whatever context happens to be
   the current one.
 */

/**
  Makes the specified surface active in the current graphics state,
  ready for use. Also, sets the device offset to specified coordinates.
 **/
- (void) GSSetSurface: (OpalSurface *)opalSurface
                     : (int)x
                     : (int)y
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  if(_opalSurface != opalSurface)
    {
      id old = _opalSurface;
      _opalSurface = [opalSurface retain];
      [old release];
    }
  
  [self setOffset: NSMakePoint(x, y)];
  [self DPSinitgraphics];  
}
- (id) GSCurrentSurface: (OpalSurface **)surface
                          : (int *)x
                          : (int *)y
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  return _opalSurface;
}
/**
  Sets up a new CG*Context() for drawing content.
  
  TODO: tell _opalSurface to create a new context
 **/
- (void) DPSinitgraphics
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  [super DPSinitgraphics];

  [_opalSurface createCGContexts];

}

@end

// MARK: Accessors
// MARK: -

@implementation OpalGState (Accessors)

- (CGContextRef) cgContext
{
  return [_opalSurface cgContext];
}

@end

// MARK: Non-required methods
// MARK: -
static CGFloat theAlpha = 1.; // TODO: removeme
@implementation OpalGState (NonrequiredMethods)

- (void) DPSsetrgbcolor: (CGFloat)r : (CGFloat)g : (CGFloat)b
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  const CGFloat alpha = 1; // TODO: is this correct?
  if(!CGCTX)
    return;
  CGContextSetRGBFillColor(CGCTX, r, g, b, alpha);
}
- (void) DPSrectfill: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h
{
  NSLog(@"%p (%@): %s - rect %g %g %g %g", self, [self class], __PRETTY_FUNCTION__, x, y, w, h);

  CGContextFillRect(CGCTX, CGRectMake(x, y, w, h));
}
- (void) DPSrectclip: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h
{
  NSLog(@"%p (%@): %s - %g %g %g %g", self, [self class], __PRETTY_FUNCTION__, x, y, w, h);
  
  [self DPSinitclip];
  CGContextClipToRect(CGCTX, CGRectMake(x, y, w, h));
}
- (void) DPSsetgray: (CGFloat)gray
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  const CGFloat alpha = 1; // TODO: is this correct?
  CGContextSetGrayFillColor(CGCTX, gray, alpha);
}
- (void) DPSsetalpha: (CGFloat)a
{
  NSLog(@"%p (%@): %s - alpha %g", self, [self class], __PRETTY_FUNCTION__, a);
  
  CGContextSetAlpha(CGCTX, a);
  theAlpha = a;
}
- (void)DPSinitmatrix 
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  OPContextSetIdentityCTM(CGCTX);
  #if 0
  // Flipping the coordinate system is NOT required
  CGContextTranslateCTM(CGCTX, 0, [_opalSurface device]->buffer_height);
  CGContextScaleCTM(CGCTX, 1, -1);
  #endif
  [super DPSinitmatrix];
}
- (void)DPSconcat: (const CGFloat *)m
{
  NSLog(@"%p (%@): %s - %g %g %g %g %g %g", self, [self class], __PRETTY_FUNCTION__, m[0], m[1], m[2], m[3], m[4], m[5]);

  CGContextConcatCTM(CGCTX, CGAffineTransformMake(
                     m[0], m[1], m[2],
                     m[3], m[4], m[5]));
  [super DPSconcat:m];
}
- (void)DPSscale: (CGFloat)x
                : (CGFloat)y 
{
  NSLog(@"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, x, y);
  
  CGContextScaleCTM(CGCTX, x, y);
}
- (void)DPStranslate: (CGFloat)x
                    : (CGFloat)y 
{
  NSLog(@"%p (%@): %s - x %g y %g", self, [self class], __PRETTY_FUNCTION__, x, y);
  
  CGContextTranslateCTM(CGCTX, x, y);
  [super DPStranslate:x:y];
}
- (void) DPSmoveto: (CGFloat) x
                  : (CGFloat) y
{
  NSLog(@"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, x, y);

  CGContextMoveToPoint(CGCTX, x, y);
}
- (void) DPSlineto: (CGFloat) x
                  : (CGFloat) y
{
  NSLog(@"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, x, y);

  CGContextAddLineToPoint(CGCTX, x, y);
}
- (void) setOffset: (NSPoint)theOffset
{
  NSLog(@"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, theOffset.x, theOffset.y);

#if 1
  if (CGCTX != nil)
    {
#if 1
      OPContextSetCairoDeviceOffset(CGCTX, -theOffset.x, 
          theOffset.y - [_opalSurface device]->buffer_height);
#else
      OPContextSetCairoDeviceOffset(CGCTX, theOffset.x, 
          theOffset.y);
#endif
    }
#else
  // This is a BAD hack using transform matrix.
  // It'll break horribly when Opal state is saved and restored.
  static NSPoint OFFSET = { 0, 0 };
  //CGContextTranslateCTM(CGCTX, -(-OFFSET.x), 
  //        -(OFFSET.y - [_opalSurface device]->buffer_height));
  CGContextTranslateCTM(CGCTX, -theOffset.x, 
          theOffset.y - [_opalSurface device]->buffer_height);
  
  OFFSET = theOffset;
#endif
  [super setOffset: theOffset];
}
/*
- (void) setColor: (device_color_t *)color state: (color_state_t)cState
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  [super setColor: color
            state: cState];
  
  switch (color->space)
    {
    case rgb_colorspace:
      if (cState & COLOR_STROKE)
        CGContextSetRGBStrokeColor(CGCTX, color->field[0],
          color->field[1], color->field[2], color->field[3]);
      if (cState & COLOR_FILL)
        CGContextSetRGBFillColor(CGCTX, color->field[0],
          color->field[1], color->field[2], color->field[3]);
      break;
    }
}
*/
@end

// MARK: Non-required unimplemented methods
// MARK: -

@implementation OpalGState (NonrequiredUnimplementedMethods)

/*
 Methods that follow have not been implemented.
 They are here to prevent GSGState implementations from
 executing.
 
 Sole criteria for picking them is looking at what methods
 are called by a dummy AppKit application with a single
 empty NSWindow.
 */

- (void) DPSsetlinewidth: (CGFloat) width
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}
/*
- (NSAffineTransform *) GSCurrentCTM
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  return nil;
}
*/

@end

@implementation OpalGState (Unused)

- (void) _setPath
{
#if 0
  NSInteger count = [path elementCount];
  NSInteger i;
  SEL elmsel = @selector(elementAtIndex:associatedPoints:);
  NSBezierPathElement (*elmidx)(id, SEL, NSInteger, NSPoint*) =
    (NSBezierPathElement (*)(id, SEL, NSInteger, NSPoint*))[path methodForSelector: elmsel];

  // reset current cairo path
  cairo_new_path(_ct);
  for (i = 0; i < count; i++) 
    {
      NSBezierPathElement type;
      NSPoint points[3];

      type = (NSBezierPathElement)(*elmidx)(path, elmsel, i, points);
      switch(type) 
        {
          case NSMoveToBezierPathElement:
            cairo_move_to(_ct, points[0].x, points[0].y);
            break;
          case NSLineToBezierPathElement:
            cairo_line_to(_ct, points[0].x, points[0].y);
            break;
          case NSCurveToBezierPathElement:
            cairo_curve_to(_ct, points[0].x, points[0].y, 
                           points[1].x, points[1].y, 
                           points[2].x, points[2].y);
            break;
          case NSClosePathBezierPathElement:
            cairo_close_path(_ct);
            break;
          default:
            break;
        }
    }
#endif
}


@end
