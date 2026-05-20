/*
   OpalSurface.m

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

#import "opal/OpalSurface.h"
#import "x11/XGServerWindow.h"

/* TODO: expose these from within opal */
extern CGContextRef OPX11ContextCreate(Display *display, Drawable drawable);
extern void OPContextSetSize(CGContextRef ctx, CGSize s);

/* Taken from GSQuartzCore's CABackingStore */
static CGContextRef createCGBitmapContext(int pixelsWide,
                                          int pixelsHigh)
{
  CGContextRef    context = NULL;
  CGColorSpaceRef colorSpace;
  int             bitmapBytesPerRow;

  bitmapBytesPerRow = (pixelsWide * 4);

  colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);

  // Let CGBitmapContextCreate() allocate the memory.
  // This should be good under Cocoa too.
  context = CGBitmapContextCreate(NULL,
                                  pixelsWide,
                                  pixelsHigh,
                                  8,      // bits per component
                                  bitmapBytesPerRow,
                                  colorSpace,
                                  kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst);

  // Note: our use of premultiplied alpha means that we need to
  // do alpha blending using:
  //  GL_SRC_ALPHA, GL_ONE

  CGColorSpaceRelease(colorSpace);
  if (context == NULL)
    {
      NSLog(@"Context not created!");
      return NULL;
    }
  return context;
}


@implementation OpalSurface

- (void) createCGContextsWithSuppliedBackingContext: (CGContextRef)ctx
{
  int pixelsWide;
  int pixelsHigh;
  // FIXME: this method and class presumes we are being passed
  // a window device.

  if (_x11CGContext || _backingCGContext)
    {
      NSLog(@"FIXME: Replacement of OpalSurface %p's CGContexts (x11=%p,backing=%p) without transfer of gstate", self, _x11CGContext, _backingCGContext);
      // Resize path: drop the old X11 CGContext so the next expose
      // recreates one at the new window size.  The backing bitmap
      // below is reallocated at the new size, too.
      if (_x11CGContext)
        {
          CGContextRelease(_x11CGContext);
          _x11CGContext = NULL;
        }
      if (_backingCGContext)
        {
          CGContextRelease(_backingCGContext);
          _backingCGContext = NULL;
        }
    }

  if (ctx)
    {
      // Client supplied a ready-made CGContext.  Treat it as the x11
      // destination (pre-existing behaviour) and derive the size from it.
      _x11CGContext = ctx;
      pixelsWide = CGBitmapContextGetWidth(ctx);
      pixelsHigh = CGBitmapContextGetHeight(ctx);
    }
  else
    {
      // Lazy path: defer creation of the X11 CGContext until the X window
      // is actually mapped.  -[NSWindow _startBackendWindow] invokes
      // GSSetDevice (which ends up here) before the window is mapped, so
      // OPX11ContextCreate() either fails or returns a context that does
      // not draw.  We instead create the X11 context on first use, which
      // is triggered by the initial Expose event (or by any GState path
      // that touches _x11CGContext).
      pixelsWide = _gsWindowDevice->buffer_width;
      pixelsHigh = _gsWindowDevice->buffer_height;

      // Ask XGServerWindow to call +[OpalContext handleExposeRect:forDriver:]
      // to let us handle the back buffer -> front buffer copy using Opal.
      _gsWindowDevice->gdriverProtocol |= GDriverHandlesExpose | GDriverHandlesBacking;
      _gsWindowDevice->gdriver = self;
    }

#if 0
  if (_gsWindowDevice->type == NSBackingStoreNonretained)
    {
      // Don't double-buffer:
      // use the window surface as the drawing destination.
    }
  else
#else
#warning All windows have to be doublebuffered
#endif
    {
      // Do double-buffer:
      // Create a similar surface to the window which supports alpha
      _backingCGContext = createCGBitmapContext(pixelsWide, pixelsHigh);
    }

  NSLog(@"OpalSurface Created CGContexts: X11=%p (deferred unless non-nil), backing=%p, width=%d height=%d",
              _x11CGContext, _backingCGContext, pixelsWide, pixelsHigh);

}

/**
 * Lazily create the X11-backed CGContext.  Called from every code path
 * that actually draws to or otherwise touches _x11CGContext.  Safe to
 * call repeatedly; only has side effects the first time (per surface
 * instance) or after an explicit invalidation.
 *
 * We do nothing unless the associated gswindow_device_t has a valid
 * X Window id (ident != 0), because OPX11ContextCreate on an unmapped
 * or zero drawable returns a context that cannot draw.
 */
- (void) ensureX11Context
{
  if (_x11CGContext != NULL)
    return;
  if (_gsWindowDevice == NULL)
    return;
  if (_gsWindowDevice->ident == 0)
    return;

  Display *display = _gsWindowDevice->display;
  Window window = _gsWindowDevice->ident;

  _x11CGContext = OPX11ContextCreate(display, window);
  if (_x11CGContext == NULL)
    {
      NSDebugLLog(@"OpalSurface",
        @"OpalSurface %p: OPX11ContextCreate(display=%p, window=%lu) returned NULL; will retry on next use",
        self, display, (unsigned long)window);
      return;
    }

  NSDebugLLog(@"OpalSurface",
    @"OpalSurface %p: lazily created X11 CGContext=%p for window=%lu",
    self, _x11CGContext, (unsigned long)window);
}

// FIXME: *VERY* bad things will happen if a non-bitmap
// context is passed here.
- (id) initWithDevice: (void *)device context: (CGContextRef)ctx
{
  self = [super init];
  if (!self)
    return nil;

  // FIXME: this method and class presumes we are being passed
  // a window device.
  _gsWindowDevice = (gswindow_device_t *) device;

  [self createCGContextsWithSuppliedBackingContext: ctx];

  return self;
}

- (void *) device
{
  return _gsWindowDevice;
}

- (CGContextRef) CGContext
{
  return _backingCGContext ? _backingCGContext : _x11CGContext;
}

- (CGContextRef) backingCGContext
{
  return _backingCGContext;
}

- (CGContextRef) x11CGContext
{
  // All external readers of the X11 context must see a valid context
  // if one can be created right now, so route through the lazy path.
  [self ensureX11Context];
  return _x11CGContext;
}

- (void) handleExposeRect: (NSRect)rect
{
  // Expose events only fire on mapped windows, so this is the first
  // safe moment at which we know the X Window is real.  Create the
  // X11 CGContext on demand if we haven't already.
  [self ensureX11Context];

  NSLog(@"OpalSurface handleExposeRect: %@ backing=%p x11=%p", NSStringFromRect(rect), _backingCGContext, _x11CGContext);
  NSDebugLLog(@"OpalSurface", @"handleExposeRect %@", NSStringFromRect(rect));

  if (!_backingCGContext || !_x11CGContext)
    {
      return;
    }

  // Flush backing context to ensure all drawing is committed
  CGContextFlush(_backingCGContext);
  CGImageRef backingImage = CGBitmapContextCreateImage(_backingCGContext);
  if (!backingImage) // FIXME: writing a nil image fails with Opal
    return;

  CGRect cgRect = CGRectMake(rect.origin.x, rect.origin.y,
                      rect.size.width, rect.size.height);
  cgRect = CGRectIntegral(cgRect);
  cgRect = CGRectIntersection(cgRect, CGRectMake(0, 0, CGImageGetWidth(backingImage), CGImageGetHeight(backingImage)));

  CGRect subimageCGRect = cgRect;
  CGImageRef subImage = CGImageCreateWithImageInRect(backingImage, subimageCGRect);

  CGContextSaveGState(_x11CGContext);
  OPContextResetClip(_x11CGContext);
  OPContextSetIdentityCTM(_x11CGContext);

  cgRect.origin.y = [self size].height - cgRect.origin.y - cgRect.size.height;
  NSDebugLLog(@"OpalSurface", @" ... actually from %@ to %@", NSStringFromRect(*(NSRect *)&subimageCGRect), NSStringFromRect(*(NSRect *)&cgRect));


  CGContextDrawImage(_x11CGContext, cgRect, subImage);
  CGContextFlush(_x11CGContext);

#if 0
#warning Saving debug images
  [self _saveImage: backingImage withPrefix:@"/tmp/opalback-backing-" size: CGSizeZero];
  [self _saveImage: subImage withPrefix:@"/tmp/opalback-subimage-" size: subimageCGRect.size ];
#endif

  CGImageRelease(backingImage);
  CGImageRelease(subImage);
  CGContextRestoreGState(_x11CGContext);
}

- (void) _saveImage: (CGImageRef) img withPrefix: (NSString *) prefix size: (CGSize) size
{
#if 1
#warning Opal bug: cannot properly save subimage created with CGImageCreateWithImageInRect()
  if (size.width != 0 || size.height != 0)
    {
      CGContextRef tmp = createCGBitmapContext(size.width, size.height);
      CGContextDrawImage(tmp, CGRectMake(0, 0, size.width, size.height), img);
      img = CGBitmapContextCreateImage(tmp);
      [(id)img autorelease];
    }
#endif

  // FIXME: Opal tries to access -path from CFURLRef
  //CFURLRef fileUrl = CFURLCreateWithFileSystemPath(NULL, @"/tmp/opalback.jpg", kCFURLPOSIXPathStyle, NO);
  NSString * path = [NSString stringWithFormat: @"%@%dx%d.png", prefix, CGImageGetWidth(img), CGImageGetHeight(img)];
  CFURLRef fileUrl = (CFURLRef)[[NSURL fileURLWithPath: path] retain];
  NSLog(@"FileURL %@", fileUrl);
  //CGImageDestinationRef outfile = CGImageDestinationCreateWithURL(fileUrl, @"public.jpeg"/*kUTTypeJPEG*/, 1, NULL);
  CGImageDestinationRef outfile = CGImageDestinationCreateWithURL(fileUrl, @"public.png"/*kUTTypePNG*/, 1, NULL);
  CGImageDestinationAddImage(outfile, img, NULL);
  CGImageDestinationFinalize(outfile);
  CFRelease(fileUrl);
  CFRelease(outfile);
}

- (BOOL) isDrawingToScreen
{
  // TODO: stub
  return YES;
}

- (NSSize) size
{
  return NSMakeSize(CGBitmapContextGetWidth(_backingCGContext),
                    CGBitmapContextGetHeight(_backingCGContext));
}

@end
