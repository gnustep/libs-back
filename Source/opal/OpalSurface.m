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
static CGContextRef createCGBitmapContext (int pixelsWide,
                                             int pixelsHigh)
{
  CGContextRef    context = NULL;
  CGColorSpaceRef colorSpace;
  void *          bitmapData;
  int             bitmapByteCount;
  int             bitmapBytesPerRow;
  
  bitmapBytesPerRow   = (pixelsWide * 4);
  bitmapByteCount     = (bitmapBytesPerRow * pixelsHigh);
  
  colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);// 2

  // Let CGBitmapContextCreate() allocate the memory.
  // This should be good under Cocoa too.
  bitmapData = NULL;

  context = CGBitmapContextCreate (bitmapData,
                                   pixelsWide,
                                   pixelsHigh,
                                   8,      // bits per component
                                   bitmapBytesPerRow,
                                   colorSpace,
#if !GNUSTEP
                                   kCGImageAlphaPremultipliedLast);
#else
  // Opal only supports kCGImageAlphaPremultipliedFirst.
  // However, this is incorrect since it implies ARGB.
                                  kCGImageAlphaPremultipliedFirst);
#endif

  // Note: our use of premultiplied alpha means that we need to
  // do alpha blending using:
  //  GL_SRC_ALPHA, GL_ONE

  CGColorSpaceRelease(colorSpace);
  if (context== NULL)
    {
      free (bitmapData);// 5
      fprintf (stderr, "Context not created!");
      return NULL;
    }

#if GNUSTEP
#warning Opal bug: context should be cleared automatically

#if 0
  CGContextClearRect (context, CGRectInfinite);
#else
#warning Opal bug: CGContextClearRect() permanently whacks the context
  memset (CGBitmapContextGetData (context), 
          0, bitmapBytesPerRow * pixelsHigh);
#endif
#endif  
  return context;
}


@implementation OpalSurface

- (id) initWithDevice: (void *)device
{
  self = [super init];
  if (!self)
    return nil;

  // FIXME: this method and class presumes we are being passed
  // a window device.
  _gsWindowDevice = (gswindow_device_t *) device;

  Display * display = _gsWindowDevice->display;
  Window window = _gsWindowDevice->ident;
  _x11CGContext = OPX11ContextCreate(display, window);
  
  if (_gsWindowDevice->type == NSBackingStoreNonretained)
    {
      // Don't double-buffer:
      // use the window surface as the drawing destination.
    }
  else
    {
      // Do double-buffer:
      // Create a similar surface to the window which supports alpha

      // Ask XGServerWindow to call +[OpalContext handleExposeRect:forDriver:]
      // to let us handle the back buffer -> front buffer copy using Opal.
      _gsWindowDevice->gdriverProtocol |= GDriverHandlesExpose | GDriverHandlesBacking;
      _gsWindowDevice->gdriver = self;

#if 0
      // Disabled because when the content is blitted onto the screen,
      // we get just yellow blots instead of actual content.
      _backingCGContext = createCGBitmapContext(
                       _gsWindowDevice->buffer_width, 
                       _gsWindowDevice->buffer_height);
#endif
    }
  
  return self;
}

- (gswindow_device_t *) device
{
  return _gsWindowDevice;
}

- (CGContextRef) cgContext
{
  return _backingCGContext ? _backingCGContext : _x11CGContext;
}

- (void) handleExposeRect: (NSRect)rect
{
  CGRect cgRect = CGRectMake(rect.origin.x, rect.origin.y, 
                      rect.size.width, rect.size.height);
  
  CGImageRef backingImage = CGBitmapContextCreateImage(_backingCGContext);
  if (!backingImage) // FIXME: writing a nil image fails with Opal
    return;
    
  CGContextDrawImage(_x11CGContext, cgRect, backingImage);
  
  // FIXME: Opal tries to access -path from CFURLRef
  //CFURLRef fileUrl = CFURLCreateWithFileSystemPath(NULL, @"/tmp/opalback.jpg", kCFURLPOSIXPathStyle, NO);
  CFURLRef fileUrl = (CFURLRef)[[NSURL fileURLWithPath: @"/tmp/opalback.jpg"] retain];
  CGImageDestinationRef outfile = CGImageDestinationCreateWithURL(fileUrl, @"public.jpeg"/*kUTTypeJPEG*/, 1, NULL);
  CGImageDestinationAddImage(outfile, backingImage, NULL);
  CGImageDestinationFinalize(outfile);
  CFRelease(fileUrl);
  CFRelease(outfile);
  
  
  CGImageRelease(backingImage);
}

- (BOOL) isDrawingToScreen
{
  // TODO: stub
  return YES;
}

- (void) dummyDraw
{

  NSLog(@"performing dummy draw");
  
  CGContextSaveGState([self cgContext]);

  CGRect r = CGRectMake(0, 0, 1024, 1024);
  CGContextSetRGBFillColor([self cgContext], 1, 0, 0, 1);
  CGContextFillRect([self cgContext], r);

  CGContextRestoreGState([self cgContext]);

}

@end
