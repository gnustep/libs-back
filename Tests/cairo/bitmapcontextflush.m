/* A graphics context whose destination is an NSBitmapImageRep is not attached
 * to a window, so it has no window server behind it.  Flushing such a context
 * has to be harmless: the x11 flush reaches for the server of the context, and
 * with no window there is nothing to ask.
 *
 * It needs a running window server to create the context at all, so it skips
 * cleanly when there is none, and guards on the cairo graphics backend.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <stdlib.h>

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  NSBitmapImageRep *rep;
  NSGraphicsContext *ctxt;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping bitmap context flush test");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  rep = AUTORELEASE([[NSBitmapImageRep alloc]
    initWithBitmapDataPlanes: NULL
                  pixelsWide: 8
                  pixelsHigh: 8
               bitsPerSample: 8
             samplesPerPixel: 4
                    hasAlpha: YES
                    isPlanar: NO
              colorSpaceName: NSDeviceRGBColorSpace
                 bytesPerRow: 0
                bitsPerPixel: 0]);

  ctxt = [NSGraphicsContext graphicsContextWithBitmapImageRep: rep];
  PASS(ctxt != nil,
       "a graphics context can be made for a bitmap representation");

  [NSGraphicsContext saveGraphicsState];
  [NSGraphicsContext setCurrentContext: ctxt];
  [ctxt flushGraphics];
  [NSGraphicsContext restoreGraphicsState];

  PASS([NSGraphicsContext currentContext] != ctxt,
       "flushing a bitmap context leaves the graphics state stack in step");

  DESTROY(pool);
  return 0;
}

#else

int
main(int argc, const char **argv)
{
  return 0;
}

#endif
