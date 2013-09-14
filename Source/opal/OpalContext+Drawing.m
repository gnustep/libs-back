/*
   OpalContext+Drawing.m

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
#import <AppKit/NSGraphics.h> // NS*ColorSpace
#import <AppKit/NSBitmapImageRep.h> // NSBitmapImageRep
#import "opal/OpalContext+Drawing.h"
#import "opal/OpalSurface.h"
#import "x11/XGServerWindow.h"

#define CGCTX [self cgContext]
#define NULL_CGCTX_CHECK(what) \
  if(![_opalSurface cgContext]) \
    { \
      NSLog(@"%p: No CG context while in %s", self, __PRETTY_FUNCTION__); \
      /*raise(SIGSTOP);*/ \
      return what; \
    }

@implementation OpalContext(Drawing)

// MARK: Minimum required methods
// MARK: -

- (void) DPSinitclip
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  NULL_CGCTX_CHECK();

  OPContextResetClip(CGCTX);
}

- (void) DPSclip
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  NULL_CGCTX_CHECK();

  CGContextClip(CGCTX);
}

- (void) DPSfill
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  NULL_CGCTX_CHECK();

  CGContextFillPath(CGCTX);
}

- (void) DPSimage: (NSAffineTransform *)matrix
                 : (NSInteger)pixelsWide
		 : (NSInteger)pixelsHigh
                 : (NSInteger)bitsPerSample // is this used correctly ?
		 : (NSInteger)samplesPerPixel // < unused
                 : (NSInteger)bitsPerPixel
		 : (NSInteger)bytesPerRow
                 : (BOOL)isPlanar // < unused
		 : (BOOL)hasAlpha // < unused
                 : (NSString *)colorSpaceName
		 : (const unsigned char *const[5])data
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
 
  NULL_CGCTX_CHECK();
  // This depends on CGAffineTransform and NSAffineTransformStruct having 
  // the same in-memory layout.
  // Here's an elementary check if that is true.
  // We should probably check this in -back's "configure" script.
  assert(sizeof(CGAffineTransform) == sizeof(NSAffineTransformStruct));
  NSAffineTransformStruct nsAT = [matrix transformStruct];
  CGAffineTransform cgAT = *(CGAffineTransform *)&nsAT;

  CGContextSaveGState(CGCTX);
//  CGContextSetRGBFillColor(CGCTX, 1, 0, 0, 1);
  CGContextConcatCTM(CGCTX, cgAT);
//  CGContextFillRect(CGCTX, CGRectMake(0, 0, pixelsWide, pixelsHigh));

  // TODO:
  // We may want to normalize colorspace names between Opal and -gui,
  // to avoid this conversion?
  NSLog(@"Colorspace %@", colorSpaceName);
  if ([colorSpaceName isEqualToString:NSCalibratedRGBColorSpace])
    colorSpaceName = kCGColorSpaceGenericRGB; // SRGB?
  else if ([colorSpaceName isEqualToString:NSDeviceRGBColorSpace])
    colorSpaceName = kCGColorSpaceGenericRGB;

  // TODO: bitsPerComponent (in variable bitsPerSample) is not
  // liked combined with bitsBerPixel
  else if ([colorSpaceName isEqualToString:NSCalibratedWhiteColorSpace])
    colorSpaceName = kCGColorSpaceGenericGray;
  else if ([colorSpaceName isEqualToString:NSDeviceWhiteColorSpace])
    colorSpaceName = kCGColorSpaceGenericGray;

  else
    {
      NSLog(@"Opal backend: Unhandled colorspace: %@", colorSpaceName);
      CGContextRestoreGState(CGCTX);
      return;
    }

  if (bitsPerPixel != 32)
    {
      NSLog(@"Bits per pixel: %d - the only verified combination is 32", bitsPerPixel);
      CGContextRestoreGState(CGCTX);
      return;
    }
  //CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(colorSpaceName);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
#if 0
  NSData * nsData = [NSData dataWithBytesNoCopy: *data
                                         length: pixelsHigh * bytesPerRow];
#else
  #warning Using suboptimal '-dataWithBytes:length:' because NoCopy variant breaks down
  NSData * nsData = [NSData dataWithBytes: *data
                                   length: pixelsHigh * bytesPerRow];
#endif

  CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData(nsData);
NSLog(@"Bits per component : bitspersample = %d", bitsPerSample);
NSLog(@"Bits per pixel     : bitsperpixel = %d", bitsPerPixel);
NSLog(@"                   : samplesperpixel = %d", samplesPerPixel);
  CGImageRef img = CGImageCreate(pixelsWide, pixelsHigh, bitsPerSample,
                                 bitsPerPixel, bytesPerRow, colorSpace,
                                 hasAlpha ? kCGImageAlphaPremultipliedLast : 0 /* correct? */,
                                 dataProvider,
                                 NULL /* const CGFloat decode[] is what? */,
                                 false, /* shouldInterpolate? */
                                 kCGRenderingIntentDefault );
  CGContextDrawImage(CGCTX, CGRectMake(0, 0, pixelsWide, pixelsHigh), img);
  CGDataProviderRelease(dataProvider);
  CGImageRelease(img);
  CGContextRestoreGState(CGCTX);
}
/*
- (void) compositeGState: (OpalGState *)source
                fromRect: (NSRect)srcRect 
                 toPoint: (NSPoint)destPoint 
                      op: (NSCompositingOperation)op
                fraction: (CGFloat)delta
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
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
*/
- (void) DPScompositerect: (CGFloat)x
                         : (CGFloat)y
                         : (CGFloat)w
                         : (CGFloat)h
                         : (NSCompositingOperation)op
{
  NSRect aRect = NSMakeRect(x, y, w, h);

  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s - %@", self, [self class], __PRETTY_FUNCTION__, NSStringFromRect(aRect));

  NULL_CGCTX_CHECK();

  CGContextSaveGState(CGCTX);
  //[self DPSinitmatrix];

  CGContextFillRect(CGCTX, CGRectMake(aRect.origin.x,  [_opalSurface device]->buffer_height -  aRect.origin.y, 
    aRect.size.width, aRect.size.height));
  CGContextRestoreGState(CGCTX); 
}

- (void) DPSsetdash: (const CGFloat*)pat
                   : (NSInteger)size
                   : (CGFloat)offset
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  // TODO: stub
}
- (void) DPSstroke
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  CGContextStrokePath(CGCTX);
}

- (void) DPSsetlinejoin: (int)linejoin
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  // TODO: stub
}
- (void) DPSsetlinecap: (int)linecap
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  // TODO: stub
}
- (void) DPSsetmiterlimit: (CGFloat)miterlimit
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  // TODO: stub
}

/**
  Makes the specified surface active in the current graphics state,
  ready for use. Also, sets the device offset to specified coordinates.
 **/
- (void) GSSetSurface: (OpalSurface *)opalSurface
                     : (int)x
                     : (int)y
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  if(_opalSurface != opalSurface)
    {
      id old = _opalSurface;
      _opalSurface = [opalSurface retain];
      [old release];
    }
  
  NSLog(@"Set surface to %p", _opalSurface);
  [self setOffset: NSMakePoint(x, y)];
  [self DPSinitgraphics];  
}
- (id) GSCurrentSurface: (OpalSurface **)surface
                          : (int *)x
                          : (int *)y
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  return _opalSurface;
}
/**
  Sets up a new CG*Context() for drawing content.
 **/
- (void) DPSinitgraphics
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  [_opalSurface createCGContexts];
/*
  if ([_opalSurface device])
    {
      CGContextTranslateCTM(CGCTX, 0, [_opalSurface device]->buffer_height);
      CGContextScaleCTM(CGCTX, 1, -1);
    }
*/
}

@end

// MARK: Accessors
// MARK: -

@implementation OpalContext (DrawingAccessors)

- (CGContextRef) cgContext
{
  if (!_opalSurface)
    NSDebugMLLog(@"OpalContextDrawing", @"No OpalSurface");
  else if (![_opalSurface cgContext])
    NSDebugMLLog(@"OpalContextDrawing", @"No OpalSurface CGContext");
  return [_opalSurface cgContext];
}

@end

// MARK: Non-required methods
// MARK: -
static CGFloat theAlpha = 1.; // TODO: removeme
@implementation OpalContext (DrawingNonrequiredMethods)

- (void) DPSsetrgbcolor: (CGFloat)r : (CGFloat)g : (CGFloat)b
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  const CGFloat alpha = 1; // TODO: is this correct?
  if(!CGCTX)
    return;
  CGContextSetRGBStrokeColor(CGCTX, r, g, b, alpha);
  CGContextSetRGBFillColor(CGCTX, r, g, b, alpha);
}
- (void) DPSrectfill: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s - rect %g %g %g %g", self, [self class], __PRETTY_FUNCTION__, x, y, w, h);

  NULL_CGCTX_CHECK();

  CGContextFillRect(CGCTX, CGRectMake(x, y, w, h));
}
- (void) DPSrectclip: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s - %g %g %g %g", self, [self class], __PRETTY_FUNCTION__, x, y, w, h);
  
  NULL_CGCTX_CHECK();

  [self DPSinitclip];
  CGContextClipToRect(CGCTX, CGRectMake(x, y, w, h));
}
- (void) DPSsetgray: (CGFloat)gray
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  NULL_CGCTX_CHECK();

  const CGFloat alpha = 1; // TODO: is this correct?
  CGContextSetGrayFillColor(CGCTX, gray, alpha);
}
- (void) DPSsetalpha: (CGFloat)a
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s - alpha %g", self, [self class], __PRETTY_FUNCTION__, a);
  
  NULL_CGCTX_CHECK();

  CGContextSetAlpha(CGCTX, a);
  theAlpha = a;
}
- (void)DPSinitmatrix 
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  NULL_CGCTX_CHECK();
  
  OPContextSetIdentityCTM(CGCTX);
  #if 0
  // Flipping the coordinate system is NOT required
  CGContextTranslateCTM(CGCTX, 0, [_opalSurface device]->buffer_height);
  CGContextScaleCTM(CGCTX, 1, -1);
  #endif
}
- (void)DPSconcat: (const CGFloat *)m
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s - %g %g %g %g %g %g", self, [self class], __PRETTY_FUNCTION__, m[0], m[1], m[2], m[3], m[4], m[5]);

  CGContextConcatCTM(CGCTX, CGAffineTransformMake(
                     m[0], m[1], m[2],
                     m[3], m[4], m[5]));
}
- (void)DPSscale: (CGFloat)x
                : (CGFloat)y 
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, x, y);
  
  NULL_CGCTX_CHECK();

  CGContextScaleCTM(CGCTX, x, y);
}
- (void)DPStranslate: (CGFloat)x
                    : (CGFloat)y 
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s - x %g y %g", self, [self class], __PRETTY_FUNCTION__, x, y);
  
  NULL_CGCTX_CHECK();

  CGContextTranslateCTM(CGCTX, x, y);
}
- (void) DPSmoveto: (CGFloat) x
                  : (CGFloat) y
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, x, y);

  NULL_CGCTX_CHECK();

  CGContextMoveToPoint(CGCTX, x, y);
}
- (void) DPSlineto: (CGFloat) x
                  : (CGFloat) y
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, x, y);

  NULL_CGCTX_CHECK();

  CGContextAddLineToPoint(CGCTX, x, y);
}
- (void) setOffset: (NSPoint)theOffset
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, theOffset.x, theOffset.y);

  NULL_CGCTX_CHECK();

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
}
/*
- (void) setColor: (device_color_t *)color state: (color_state_t)cState
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
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
- (NSAffineTransform *) GSCurrentCTM
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  NULL_CGCTX_CHECK(nil);

  CGAffineTransform cgCTM = CGContextGetCTM(CGCTX);
  NSAffineTransform * affineTransform = [NSAffineTransform transform];

  // This depends on CGAffineTransform and NSAffineTransformStruct having 
  // the same in-memory layout.
  // Here's an elementary check if that is true.
  // We should probably check this in -back's "configure" script.
  assert(sizeof(CGAffineTransform) == sizeof(NSAffineTransformStruct));

  NSAffineTransformStruct nsCTM = *(NSAffineTransformStruct *)&cgCTM;
  [affineTransform setTransformStruct: nsCTM];
  
  return affineTransform;
}
- (void) flushGraphics
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  CGContextFlush(CGCTX);
  [_opalSurface handleExpose:CGRectMake(0, 0, 1024, 1024)];
}
- (void) DPSgsave
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
#warning Opal bug: nil ctx should 'only' print a warning instead of crashing
  if (CGCTX)
    CGContextSaveGState(CGCTX);
}
- (void) DPSgrestore
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
#warning Opal bug: nil ctx should 'only' print a warning instead of crashing
  if (CGCTX)
    CGContextRestoreGState(CGCTX);
}
- (void *) saveClip
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  CGRect * r = calloc(sizeof(CGRect), 1);
  *r = CGContextGetClipBoundingBox(CGCTX);
  return r;
}
- (void) restoreClip: (void *)savedClip
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  OPContextResetClip(CGCTX);
  CGContextClipToRect(CGCTX, *(CGRect *)savedClip);
  free(savedClip);
}
- (void) DPSeoclip
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  CGContextEOClip(CGCTX);
}
- (void) DPSeofill
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  CGContextEOFillPath(CGCTX);
}
- (void) DPSshow: (const char *)s
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  CGContextSaveGState(CGCTX);
  CGContextSetRGBFillColor(CGCTX, 0, 1, 0, 1);
  CGContextFillRect(CGCTX, CGRectMake(0, 0, 12, strlen(s) * 12));
  CGContextRestoreGState(CGCTX);
}
- (void) GSShowText: (const char *)s  : (size_t) length
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
 /* 
  const char * s2 = calloc(s, length+1);
  strcpy(s2, s);
*/
  CGContextSaveGState(CGCTX);
  CGContextSetRGBFillColor(CGCTX, 0, 1, 0, 1);
  CGContextFillRect(CGCTX, CGRectMake(0, 0, 12, length * 12));
  CGContextRestoreGState(CGCTX);
//  free(s2);
}
- (void) GSShowGlyphsWithAdvances: (const NSGlyph *)glyphs : (const NSSize *)advances : (size_t) length
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  CGContextSaveGState(CGCTX);
  CGContextSetRGBFillColor(CGCTX, 0, 1, 0, 1);
  CGContextFillRect(CGCTX, CGRectMake(0, 0, 12, length * 12));
  CGContextRestoreGState(CGCTX);
  
}
#if 0
- (void) DPSrlineto: (CGFloat) x
                   : (CGFloat) y
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, x, y);

  CGContextAddRelativeLine(CGCTX, x, y);
}
#else
#warning -DPSrlineto:: not implemented directly
#endif
- (void) DPScurrentpoint: (CGFloat *)x
                        : (CGFloat *)y
{
  CGPoint currentPoint = CGContextGetPathCurrentPoint(CGCTX);

  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, currentPoint.x, currentPoint.y);

  *x = currentPoint.x;
  *y = currentPoint.y;
}
@end

// MARK: Non-required unimplemented methods
// MARK: -

@implementation OpalContext (DrawingNonrequiredUnimplementedMethods)

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
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}
- (void) DPSsetgstate: (NSInteger) gst
{
  NSDebugLLog(@"OpalContextDrawing", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  NSLog(@"Warning: application tried to set gstate directly");
}

@end

@implementation OpalContext (DrawingUnused)

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

@implementation OpalContext (DrawingGSCReplicas)
- (void) GSDrawImage: (NSRect) rect : (void *) imageref
{
  NSBitmapImageRep *bitmap;
  unsigned char *data[5];

  bitmap = (NSBitmapImageRep*)imageref;
  if (![self isCompatibleBitmap: bitmap])
    {
      NSInteger bitsPerSample = 8;
      BOOL isPlanar = NO;
      NSInteger samplesPerPixel = [bitmap hasAlpha] ? 4 : 3;
      NSString *colorSpaceName = NSCalibratedRGBColorSpace;
      NSBitmapImageRep *new;

     new = [bitmap _convertToFormatBitsPerSample: bitsPerSample
                    samplesPerPixel: samplesPerPixel
                    hasAlpha: [bitmap hasAlpha]
                    isPlanar: isPlanar
                    colorSpaceName: colorSpaceName
                    bitmapFormat: 0
                    bytesPerRow: 0
                    bitsPerPixel: 0];

      if (new == nil)
        {
          NSLog(@"Could not convert bitmap data");
          return;
        }
      bitmap = new;
    }

  [bitmap getBitmapDataPlanes: data];
  [self NSDrawBitmap: rect : [bitmap pixelsWide] : [bitmap pixelsHigh]
        : [bitmap bitsPerSample] : [bitmap samplesPerPixel]
        : [bitmap bitsPerPixel] : [bitmap bytesPerRow] : [bitmap isPlanar]
        : [bitmap hasAlpha] :  [bitmap colorSpaceName]
        : (const unsigned char**)data];
}

- (void) NSDrawBitmap: (NSRect) rect : (NSInteger) pixelsWide : (NSInteger) pixelsHigh
                     : (NSInteger) bitsPerSample : (NSInteger) samplesPerPixel
                     : (NSInteger) bitsPerPixel : (NSInteger) bytesPerRow : (BOOL) isPlanar
                     : (BOOL) hasAlpha : (NSString *) colorSpaceName
                     : (const unsigned char *const [5]) data
{
  NSAffineTransform *trans;
  NSSize scale;

  // Compute the transformation matrix
  scale = NSMakeSize(NSWidth(rect) / pixelsWide,
                     NSHeight(rect) / pixelsHigh);
  trans = [NSAffineTransform transform];
  [trans translateToPoint: rect.origin];
  [trans scaleXBy: scale.width  yBy: scale.height];

  /* This does essentially what the DPS...image operators do, so
     as to avoid an extra method call */
  [self   DPSimage: trans
                  : pixelsWide : pixelsHigh
                  : bitsPerSample : samplesPerPixel
                  : bitsPerPixel : bytesPerRow
                  : isPlanar
                  : hasAlpha : colorSpaceName
                  : data];
}
- (BOOL) isCompatibleBitmap: (NSBitmapImageRep*)bitmap
{
  return ([bitmap bitmapFormat] == 0);
}

- (void) GSSetCTM: (NSAffineTransform *)ctm
{
  /* TODO: unimplemented */
}
@end
