/* Tests CairoContext's -isCompatibleBitmap:, which decides whether a bitmap can
 * be drawn directly by the cairo backend: it must be a non-planar, 8-bit-per-
 * sample, standard-format RGB bitmap.  Anything else (planar, 16-bit, gray, or
 * a non-zero bitmap format such as alpha-first) is not compatible.
 *
 * It needs a window server (to load the backend), so it opens the display named
 * by the environment and skips when there is none, and it guards on the cairo
 * graphics backend being the one built.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <stdlib.h>

@interface NSObject (CairoCompat)
- (BOOL) isCompatibleBitmap: (NSBitmapImageRep*)bitmap;
@end

static NSBitmapImageRep *
makeRep(int spp, int bps, BOOL alpha, BOOL planar, NSString *cs)
{
  return [[[NSBitmapImageRep alloc]
    initWithBitmapDataPlanes: NULL pixelsWide: 2 pixelsHigh: 2
                bitsPerSample: bps samplesPerPixel: spp hasAlpha: alpha
                     isPlanar: planar colorSpaceName: cs
                  bytesPerRow: 0 bitsPerPixel: 0] autorelease];
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  NSImage *img;
  id ctxt;
  NSBitmapImageRep *alphaFirst;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping compatible-bitmap tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  img = [[NSImage alloc] initWithSize: NSMakeSize(4, 4)];
  [img lockFocus];
  ctxt = [NSGraphicsContext currentContext];
  PASS([ctxt isKindOfClass: NSClassFromString(@"CairoContext")],
    "the current context is a CairoContext");

  PASS([ctxt isCompatibleBitmap:
      makeRep(3, 8, NO, NO, NSDeviceRGBColorSpace)],
    "an 8-bit device-rgb bitmap is compatible");
  PASS([ctxt isCompatibleBitmap:
      makeRep(4, 8, YES, NO, NSDeviceRGBColorSpace)],
    "an 8-bit device-rgb bitmap with alpha is compatible");
  PASS([ctxt isCompatibleBitmap:
      makeRep(3, 8, NO, NO, NSCalibratedRGBColorSpace)],
    "an 8-bit calibrated-rgb bitmap is compatible");

  PASS(![ctxt isCompatibleBitmap:
      makeRep(3, 16, NO, NO, NSDeviceRGBColorSpace)],
    "a 16-bit bitmap is not compatible");
  PASS(![ctxt isCompatibleBitmap:
      makeRep(3, 8, NO, YES, NSDeviceRGBColorSpace)],
    "a planar bitmap is not compatible");
  PASS(![ctxt isCompatibleBitmap:
      makeRep(1, 8, NO, NO, NSDeviceWhiteColorSpace)],
    "a gray bitmap is not compatible");

  alphaFirst = [[[NSBitmapImageRep alloc]
    initWithBitmapDataPlanes: NULL pixelsWide: 2 pixelsHigh: 2
                bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES
                     isPlanar: NO colorSpaceName: NSDeviceRGBColorSpace
                 bitmapFormat: NSAlphaFirstBitmapFormat
                  bytesPerRow: 0 bitsPerPixel: 0] autorelease];
  PASS(![ctxt isCompatibleBitmap: alphaFirst],
    "a bitmap with a non-zero bitmap format is not compatible");

  [img unlockFocus];
  [img release];
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
