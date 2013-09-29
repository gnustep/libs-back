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
#import <AppKit/NSGraphics.h> // NS*ColorSpace
#import <AppKit/NSAffineTransform.h>
#import <AppKit/NSBezierPath.h>
#import "opal/OpalGState.h"
#import "opal/OpalSurface.h"
#import "opal/OpalFontInfo.h"

#define CGCTX [self CGContext]

static inline NSString * _CGRectRepr(CGRect rect)
{
  return [NSString stringWithFormat: @"(%g,%g,%g,%g)",
          rect.origin.x, rect.origin.y,
          rect.size.width, rect.size.height];
}

static inline CGRect _CGRectFromNSRect(NSRect nsrect)
{
  return CGRectMake(nsrect.origin.x, nsrect.origin.y,
                    nsrect.size.width, nsrect.size.height);
}

@implementation OpalGState

- (id)copyWithZone: (NSZone *)zone
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  OpalGState * theCopy = (OpalGState *) [super copyWithZone: zone];

  [_opalSurface retain];
  if (CGCTX)
    {
      theCopy->_opGState = OPContextCopyGState(CGCTX);
    }
  else
    {
      // FIXME: perhaps Opal could provide an API for getting the default
      // gstate?
      CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
      CGContextRef ctx = CGBitmapContextCreate(NULL, 1, 1, 8, 32, colorSpace, kCGImageAlphaPremultipliedFirst);
      CGColorSpaceRelease(colorSpace);
      theCopy->_opGState = OPContextCopyGState(ctx);
      CGContextRelease(ctx);
      NSDebugLLog(@"OpalGState", @"Included default gstate %p", theCopy->_opGState);
    }

  return theCopy;
}

- (void) setOffset: (NSPoint)theOffset
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, theOffset.x, theOffset.y);

  if (CGCTX != nil)
    {
      OPContextSetCairoDeviceOffset(CGCTX, -theOffset.x, 
          theOffset.y - [_opalSurface size].height);
    }
  [super setOffset: theOffset];
}

@end

@implementation OpalGState (Ops)

- (void) DPSsetalpha: (CGFloat)a
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s - alpha %g", self, [self class], __PRETTY_FUNCTION__, a);
  
  if (CGCTX)
    {
      CGContextSetAlpha(CGCTX, a);
    }
  [super DPSsetalpha: a];
}

- (void) DPSsetgray: (CGFloat)gray
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  const CGFloat alpha = 1; // TODO: is this correct?
  if (CGCTX)
    {
      CGContextSetGrayFillColor(CGCTX, gray, alpha);
    }
  [super DPSsetgray: gray];
}

- (void) DPSsetrgbcolor: (CGFloat)r : (CGFloat)g : (CGFloat)b
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  const CGFloat alpha = 1; // TODO: is this correct?
  if (CGCTX)
    {
      CGContextSetRGBStrokeColor(CGCTX, r, g, b, alpha);
      CGContextSetRGBFillColor(CGCTX, r, g, b, alpha);
    }
  [super DPSsetrgbcolor: r : g : b];
}


- (void) DPSshow: (const char *)s
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  CGContextSaveGState(CGCTX);
  CGContextSetRGBFillColor(CGCTX, 0, 1, 0, 1);
  CGContextFillRect(CGCTX, CGRectMake(0, 0, strlen(s) * 12, 12));
  CGContextRestoreGState(CGCTX);
}

- (void) GSShowText: (const char *)s  : (size_t) length
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  CGContextSaveGState(CGCTX);
  CGContextSetRGBFillColor(CGCTX, 0, 1, 0, 1);
  CGContextFillRect(CGCTX, CGRectMake(0, 0, length * 12, 12));
  CGContextRestoreGState(CGCTX);

  // TODO: implement!
}

- (void) GSSetFont: (GSFontInfo *)fontref
{
  const CGFloat * matrix;
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  [super GSSetFont: fontref];

  CGFontRef opalFont = (CGFontRef)[((OpalFontInfo *)fontref)->_faceInfo fontFace];
  CGContextSetFont(CGCTX, opalFont); 

  CGContextSetFontSize(CGCTX, 1);
  matrix = [fontref matrix];
  CGAffineTransform cgAT = CGAffineTransformMake(matrix[0], matrix[1],
                                                 matrix[2], matrix[3],
                                                 matrix[4], matrix[5]);
  CGContextSetTextMatrix(CGCTX, cgAT);
}

- (void) GSShowGlyphsWithAdvances: (const NSGlyph *)glyphs : (const NSSize *)advances : (size_t) length
{
  size_t i;
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  // NSGlyph = unsigned int, CGGlyph = unsigned short

  CGGlyph cgglyphs[length];
  for (i=0; i<length; i++)
    {
      cgglyphs[i] = glyphs[i];
    }

  CGPoint pt = CGContextGetPathCurrentPoint(CGCTX);
  // FIXME: why * 0.66?
  pt.y += [self->font defaultLineHeightForFont] * 0.66;
  CGContextSetTextPosition(CGCTX, pt.x, pt.y);
  CGContextShowGlyphsWithAdvances(CGCTX, cgglyphs, (const CGSize *)advances, length);
}

- (NSPoint) currentPoint
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  CGPoint pt = CGContextGetPathCurrentPoint(CGCTX);
  return NSMakePoint(pt.x, pt.y);
}

- (void) DPSsetdash: (const CGFloat*)pat
                   : (NSInteger)size
                   : (CGFloat)dashOffset
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  if (!pat && size != 0)
    {
      NSLog(@"%s: null 'pat' passed with size %d. Fixing by setting size to 0.", pat, (int)size);
      size = 0;
      // TODO: looking at opal, it does not seem to have a tolerance for
      // pat=NULL although CGContextSetLineDash() explicitly specifies that
      // as a possible argument
    }
  CGContextSetLineDash(CGCTX, dashOffset, pat, size);
}

- (void) DPSsetlinecap: (int)linecap
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  // TODO: ensure match of linecap constants between Opal and DPS
  CGContextSetLineCap(CGCTX, linecap);
}

- (void) DPSsetlinejoin: (int)linejoin
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  CGContextSetLineJoin(CGCTX, linejoin);
}

- (void) DPSsetlinewidth: (CGFloat) width
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  CGContextSetLineWidth(CGCTX, width);
}

- (void) DPSsetmiterlimit: (CGFloat)miterlimit
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  CGContextSetMiterLimit(CGCTX, miterlimit);
}

- (void) DPSsetstrokeadjust: (int) b
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  // TODO: Opal doesn't implement this private API of Core Graphics
}

/* Matrix operations */
- (void)DPSconcat: (const CGFloat *)m
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s - %g %g %g %g %g %g", self, 
              [self class], __PRETTY_FUNCTION__, 
              m[0], m[1], m[2], m[3], m[4], m[5]);

  CGContextConcatCTM(CGCTX, CGAffineTransformMake(
                     m[0], m[1], m[2],
                     m[3], m[4], m[5]));
  [super DPSconcat: m];
}

- (void)DPSinitmatrix 
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  OPContextSetIdentityCTM(CGCTX);
  [super DPSinitmatrix];
}

- (void)DPSrotate: (CGFloat)angle 
{
  CGContextRotateCTM(CGCTX, angle);
  [super DPSrotate: angle];
}

- (void)DPSscale: (CGFloat)x
                : (CGFloat)y 
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, x, y);
  
  CGContextScaleCTM(CGCTX, x, y);
  [super DPSscale: x : y];
}

- (void)DPStranslate: (CGFloat)x
                    : (CGFloat)y 
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s - x %g y %g", self, [self class], __PRETTY_FUNCTION__, x, y);
  
  CGContextTranslateCTM(CGCTX, x, y);
  [super DPStranslate: x: y];
}

- (NSAffineTransform *) GSCurrentCTM
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  return [super GSCurrentCTM];

  /*
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
  */
}

- (void) GSSetCTM: (NSAffineTransform *)newCTM
{
  // This depends on CGAffineTransform and NSAffineTransformStruct having 
  // the same in-memory layout.
  // Here's an elementary check if that is true.
  // We should probably check this in -back's "configure" script.
  assert(sizeof(CGAffineTransform) == sizeof(NSAffineTransformStruct));
  NSAffineTransformStruct nsAT = [newCTM transformStruct];
  CGAffineTransform cgAT = *(CGAffineTransform *)&nsAT;

  OPContextSetIdentityCTM(CGCTX);
  CGContextConcatCTM(CGCTX, cgAT);

  [super GSSetCTM: newCTM];
}

- (void) GSConcatCTM: (NSAffineTransform *)newCTM
{
  assert(sizeof(CGAffineTransform) == sizeof(NSAffineTransformStruct));
  NSAffineTransformStruct nsAT = [newCTM transformStruct];
  CGAffineTransform cgAT = *(CGAffineTransform *)&nsAT;

  CGContextConcatCTM(CGCTX, cgAT);

  [super GSConcatCTM: newCTM];
}


// MARK: Path operations
// MARK: -

- (void) DPSarc: (CGFloat)x : (CGFloat)y : (CGFloat)r : (CGFloat)angle1 : (CGFloat)angle2 
{
  CGContextAddArc(CGCTX, x, y, r, angle1, angle2, YES);
  [super DPSarc: x : y : r : angle1 : angle2];
}

- (void) DPSarcn: (CGFloat)x : (CGFloat)y : (CGFloat)r : (CGFloat)angle1 : (CGFloat)angle2 
{
  CGContextAddArc(CGCTX, x, y, r, angle1, angle2, NO);
  [super DPSarcn: x : y : r : angle1 : angle2];
}

- (void)DPSarct: (CGFloat)x1 : (CGFloat)y1 : (CGFloat)x2 : (CGFloat)y2 : (CGFloat)r 
{
  CGContextAddArcToPoint(CGCTX, x1, y1, x1, y2, r);
  [super DPSarct: x1 : y1 : x2 : y2 : r];
}

- (void) DPSclip
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  CGContextClip(CGCTX);
  [super DPSnewpath];
}

- (void)DPSclosepath 
{
  CGContextClosePath(CGCTX);
  [super DPSclosepath];
}

- (void)DPScurveto: (CGFloat)x1 : (CGFloat)y1 : (CGFloat)x2 : (CGFloat)y2
                  : (CGFloat)x3 : (CGFloat)y3 
{
  CGContextAddCurveToPoint(CGCTX, x1, y1, x2, y2, x3, y3);
  [super DPScurveto: x1 : y1 : x2 : y2 : x3 : y3];
}

- (void) DPSeoclip
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  CGContextEOClip(CGCTX);
  [super DPSnewpath];
}

- (void) DPSeofill
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  CGContextEOFillPath(CGCTX);
  [super DPSnewpath];
}

- (void) DPSfill
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  CGContextFillPath(CGCTX);
  [super DPSnewpath];
}

- (void) DPSinitclip
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  OPContextResetClip(CGCTX);
}

- (void) DPSlineto: (CGFloat) x
                  : (CGFloat) y
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, x, y);

  CGContextAddLineToPoint(CGCTX, x, y);
  [super DPSlineto: x : y];
}

- (void) DPSmoveto: (CGFloat) x
                  : (CGFloat) y
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, x, y);

  CGContextMoveToPoint(CGCTX, x, y);
  [super DPSmoveto: x : y];
}

- (void)DPSnewpath 
{
  CGContextBeginPath(CGCTX);
  [super DPSnewpath];
}

- (void)DPSrcurveto: (CGFloat)x1 : (CGFloat)y1 : (CGFloat)x2 : (CGFloat)y2
                   : (CGFloat)x3 : (CGFloat)y3 
{
  CGFloat x, y;

  [self DPScurrentpoint: &x : &y];
  x1 += x;
  y1 += y;
  x2 += x;
  y2 += y;
  x3 += x;
  y3 += y;
  CGContextAddCurveToPoint(CGCTX, x1, y1, x2, y2, x3, y3);
  [super DPSrcurveto: x1 : y1 : x2 : y2 : x3 : y3];
}

- (void) DPSrectclip: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s - %g %g %g %g", self, [self class], __PRETTY_FUNCTION__, x, y, w, h);
  
  CGContextClipToRect(CGCTX, CGRectMake(x, y, w, h));
}

- (void) DPSrectfill: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s - rect %g %g %g %g", self, [self class], __PRETTY_FUNCTION__, x, y, w, h);

  CGContextFillRect(CGCTX, CGRectMake(x, y, w, h));
}

- (void) DPSrectstroke: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h
{
  CGContextStrokeRect(CGCTX, CGRectMake(x, y, w, h));
}

- (void) DPSrlineto: (CGFloat) x
                   : (CGFloat) y
{
  CGFloat x2, y2;
  NSDebugLLog(@"OpalGState", @"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, x, y);

  [self DPScurrentpoint: &x2 : &y2];
  x2 += x;
  y2 += y;
  CGContextAddLineToPoint(CGCTX, x, y);
  [super DPSrlineto: x : y];
}

- (void) DPSrmoveto: (CGFloat) x
                   : (CGFloat) y
{
  CGFloat x2, y2;
  NSDebugLLog(@"OpalGState", @"%p (%@): %s - %g %g", self, [self class], __PRETTY_FUNCTION__, x, y);

  [self DPScurrentpoint: &x2 : &y2];
  x2 += x;
  y2 += y;
  CGContextMoveToPoint(CGCTX, x2, y2);
  [super DPSrmoveto: x : y];
}

- (void) DPSstroke
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  
  CGContextStrokePath(CGCTX);
  [super DPSnewpath];
}

- (void) GSSendBezierPath: (NSBezierPath *)newpath
{
  NSInteger count = [newpath elementCount];
  NSInteger i;
  SEL elmsel = @selector(elementAtIndex:associatedPoints:);
  NSBezierPathElement (*elmidx)(id, SEL, NSInteger, NSPoint*) =
    (NSBezierPathElement (*)(id, SEL, NSInteger, NSPoint*))[newpath methodForSelector: elmsel];

  [super GSSendBezierPath: newpath];
  CGContextBeginPath(CGCTX);
  for (i = 0; i < count; i++) 
    {
      NSBezierPathElement type;
      NSPoint points[3];

      type = (NSBezierPathElement)(*elmidx)(newpath, elmsel, i, points);
      switch(type) 
        {
          case NSMoveToBezierPathElement:
            CGContextMoveToPoint(CGCTX, points[0].x, points[0].y);
            break;
          case NSLineToBezierPathElement:
            CGContextAddLineToPoint(CGCTX, points[0].x, points[0].y);
            break;
          case NSCurveToBezierPathElement:
            CGContextAddCurveToPoint(CGCTX, points[0].x, points[0].y, 
                           points[1].x, points[1].y, 
                           points[2].x, points[2].y);
            break;
          case NSClosePathBezierPathElement:
            CGContextClosePath(CGCTX);
            break;
          default:
            break;
        }
    }
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
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  NSDebugLLog(@"OpalGState", @"         %s - %@ - cgctx %@", __PRETTY_FUNCTION__, _opalSurface, [self CGContext]);
  // This depends on CGAffineTransform and NSAffineTransformStruct having 
  // the same in-memory layout.
  // Here's an elementary check if that is true.
  // We should probably check this in -back's "configure" script.
  assert(sizeof(CGAffineTransform) == sizeof(NSAffineTransformStruct));
  NSAffineTransformStruct nsAT = [matrix transformStruct];
  CGAffineTransform cgAT = *(CGAffineTransform *)&nsAT;

  NSDebugLLog(@"OpalGState", @"tf: %@ x %@", matrix, [self GSCurrentCTM]);
  CGContextSaveGState(CGCTX);
  CGContextConcatCTM(CGCTX, cgAT);

  // TODO:
  // We may want to normalize colorspace names between Opal and -gui,
  // to avoid this conversion?
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
NSDebugLLog(@"OpalGState", @"Bits per component : bitspersample = %d", bitsPerSample);
NSDebugLLog(@"OpalGState", @"Bits per pixel     : bitsperpixel = %d", bitsPerPixel);
NSDebugLLog(@"OpalGState", @"                   : samplesperpixel = %d", samplesPerPixel);
  CGImageRef img = CGImageCreate(pixelsWide, pixelsHigh, bitsPerSample,
                                 bitsPerPixel, bytesPerRow, colorSpace,
                                 hasAlpha ? kCGImageAlphaPremultipliedLast : 0 /* correct? */,
                                 dataProvider,
                                 NULL /* const CGFloat decode[] is what? */,
                                 false, /* shouldInterpolate? */
                                 kCGRenderingIntentDefault );
  CGContextDrawImage(CGCTX, CGRectMake(0, 0, pixelsWide, pixelsHigh), img);
//[_opalSurface _saveImage: img withPrefix:@"/tmp/opalback-dpsimage-" size: NSZeroSize];
  
  CGDataProviderRelease(dataProvider);
  CGImageRelease(img);
  CGContextRestoreGState(CGCTX);
}

- (void) compositeGState: (OpalGState *)source
                fromRect: (NSRect)srcRect 
                 toPoint: (NSPoint)destPoint 
                      op: (NSCompositingOperation)op
                fraction: (CGFloat)delta
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  CGContextRef destContexts[2] = { [_opalSurface backingCGContext], [_opalSurface x11CGContext] };

  /* x11 context needs to have correct ctm applied */
  CGContextSaveGState([_opalSurface x11CGContext]);
  OPContextSetIdentityCTM([_opalSurface x11CGContext]);
  CGContextConcatCTM([_opalSurface x11CGContext], CGContextGetCTM([_opalSurface backingCGContext]));

  int i;
  for (i = 0; i < 1; i++) // not drawing into x11cgctx after all.
    {
      CGContextRef ctx = destContexts[i];

      [self compositeGState: source
                   fromRect: srcRect
                    toPoint: destPoint
                         op: op
                   fraction: delta
              destCGContext: ctx];
    }

  /* restore x11 context's previous state */
  CGContextRestoreGState([_opalSurface x11CGContext]);
}

- (void) drawGState: (OpalGState *)source 
           fromRect: (NSRect)srcRect 
            toPoint: (NSPoint)destPoint 
                 op: (NSCompositingOperation)op
           fraction: (CGFloat)delta
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  CGContextRef destContexts[2] = { [_opalSurface backingCGContext], [_opalSurface x11CGContext] };
  int i;

  for (i = 0; i < 1; i++)
    {
      CGContextRef ctx = destContexts[i];

      [self drawGState: source
              fromRect: srcRect
               toPoint: destPoint
                    op: op
              fraction: delta
         destCGContext: ctx];
    }
}

- (void) compositeGState: (OpalGState *)source
                fromRect: (NSRect)srcRect 
                 toPoint: (NSPoint)destPoint 
                      op: (NSCompositingOperation)op
                fraction: (CGFloat)delta
           destCGContext: (CGContextRef) destCGContext
{
  // NOTE: This method seems to need to paint to X11 context, too.

  NSDebugLLog(@"OpalGState", @"%p (%@): %s - from %@ of gstate %p (cgctx %p) to %@ of %p (cgctx %p)", self, [self class], __PRETTY_FUNCTION__, NSStringFromRect(srcRect), source, [source CGContext], NSStringFromPoint(destPoint), self, [self CGContext]);

  NSSize ssize = [source->_opalSurface size];
  srcRect = [source rectInMatrixSpace: srcRect];
  destPoint = [self pointInMatrixSpace: destPoint];

  srcRect.origin.y = ssize.height-srcRect.origin.y-srcRect.size.height;

  CGRect srcCGRect = _CGRectFromNSRect(srcRect);
  CGRect destCGRect = CGRectMake(destPoint.x, destPoint.y,
                                 srcRect.size.width, srcRect.size.height);
  NSDebugLLog(@"OpalGState", @"Source cgctx: %p, self: %p - from %@ to %@ with ctm %@", [source CGContext], self, _CGRectRepr(srcCGRect), _CGRectRepr(destCGRect), [self GSCurrentCTM]);
  // FIXME: this presumes that the backing CGContext of 'source' is
  // an OpalSurface with a backing CGBitmapContext
  CGImageRef backingImage = CGBitmapContextCreateImage([source CGContext]); 
  CGImageRef subImage = CGImageCreateWithImageInRect(backingImage, srcCGRect);

  CGContextSaveGState(destCGContext);
  OPContextSetIdentityCTM(destCGContext);
  OPContextSetCairoDeviceOffset(destCGContext, 0, 0);

  // TODO: this ignores op
  // TODO: this ignores delta
  CGContextDrawImage(destCGContext, destCGRect, subImage);

  OPContextSetCairoDeviceOffset(CGCTX, -offset.x, 
      offset.y - [_opalSurface size].height);

  CGContextRestoreGState(destCGContext);

  CGImageRelease(subImage);
  CGImageRelease(backingImage);
}

/** Unlike -compositeGState, -drawGSstate fully respects the AppKit CTM but 
doesn't support to use the receiver cairo target as the source. */
/* This method is required if -[OpalContext supportsDrawGState] returns YES */
- (void) drawGState: (OpalGState *)source 
           fromRect: (NSRect)srcRect 
            toPoint: (NSPoint)destPoint 
                 op: (NSCompositingOperation)op
           fraction: (CGFloat)delta
      destCGContext: (CGContextRef)destCGContext
{
  // TODO: CairoGState has a lot more complex implementation.
  // For now, we'll just call compositeGState and live
  // with the fact that CTM is not respected.

  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  CGRect srcCGRect = CGRectMake(srcRect.origin.x, srcRect.origin.y, 
                                srcRect.size.width, srcRect.size.height);
  CGRect destCGRect = CGRectMake(destPoint.x, destPoint.y,
                                 srcRect.size.width, srcRect.size.height);
  CGImageRef backingImage = CGBitmapContextCreateImage([source CGContext]); 
  CGImageRef subImage = CGImageCreateWithImageInRect(backingImage, srcCGRect);
  // TODO: this ignores op
  // TODO: this ignores delta
  CGContextDrawImage(destCGContext, destCGRect, subImage);
  CGImageRelease(subImage);
  CGImageRelease(backingImage);
}

- (void) compositerect: (NSRect)aRect
                    op: (NSCompositingOperation)op
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s - %@", self, [self class], __PRETTY_FUNCTION__, NSStringFromRect(aRect));
  
  CGContextSaveGState(CGCTX);
  OPContextSetIdentityCTM(CGCTX);
  CGContextFillRect(CGCTX, CGRectMake(aRect.origin.x, 
    [_opalSurface size].height -  aRect.origin.y, 
    aRect.size.width, aRect.size.height));
  CGContextRestoreGState(CGCTX); 
}

@end

// MARK: Initialization methods
// MARK: -

@implementation OpalGState (InitializationMethods)

- (void) DPSinitgraphics
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  [super DPSinitgraphics];
}

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
  NSDebugLLog(@"OpalGState", @"%p (%@): %s - %@ %d %d", self, [self class], __PRETTY_FUNCTION__, opalSurface, x, y);

  ASSIGN(_opalSurface, opalSurface);
  [self setOffset: NSMakePoint(x, y)];
  [self DPSinitgraphics];  
}

- (void) GSCurrentSurface: (OpalSurface **)surface
                         : (int *)x
                         : (int *)y
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  if (x)
    *x = offset.x;
  if (y)
    *y = offset.y;
  if (surface)
    {
      *surface = _opalSurface;
    }
}

@end

// MARK: Accessors
// MARK: -

@implementation OpalGState (Accessors)

- (CGContextRef) CGContext
{
  if (!_opalSurface)
    NSDebugMLLog(@"OpalGState", @"No OpalSurface");
  else if (![_opalSurface CGContext])
    NSDebugMLLog(@"OpalGState", @"No OpalSurface CGContext");
  return [_opalSurface CGContext];
}

- (OPGStateRef) OPGState
{
  return _opGState;
}

- (void) setOPGState: (OPGStateRef)opGState
{
  ASSIGN(_opGState, opGState);
}

@end

// MARK: Non-required methods
// MARK: -
@implementation OpalGState (NonrequiredMethods)

- (void) flushGraphics
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  CGContextFlush(CGCTX);
  [_opalSurface handleExpose: [_opalSurface size]]; 
}

- (void) DPSgsave
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  if (CGCTX)
    {
      CGContextSaveGState(CGCTX);
    }
}

- (void) DPSgrestore
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  if (CGCTX)
    {
      CGContextRestoreGState(CGCTX);
    }
}

@end

@implementation OpalGState (PatternColor)

- (void *) saveClip
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  CGRect * r = calloc(sizeof(CGRect), 1);
  *r = CGContextGetClipBoundingBox(CGCTX);
  return r;
}

- (void) restoreClip: (void *)savedClip
{
  NSDebugLLog(@"OpalGState", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  OPContextResetClip(CGCTX);
  CGContextClipToRect(CGCTX, *(CGRect *)savedClip);
  free(savedClip);
}

@end
